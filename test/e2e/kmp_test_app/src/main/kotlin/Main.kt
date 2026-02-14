import androidx.compose.desktop.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.cio.*
import io.ktor.server.engine.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.server.websocket.*
import io.ktor.websocket.*
import kotlinx.coroutines.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*
import java.awt.image.BufferedImage
import java.io.ByteArrayOutputStream
import java.util.concurrent.CopyOnWriteArrayList
import javax.imageio.ImageIO

// ─── App State ───

data class ElementInfo(
    val key: String,
    val type: String,
    val text: String,
    val enabled: Boolean = true,
    val bounds: Map<String, Int> = mapOf("x" to 0, "y" to 0, "width" to 100, "height" to 30)
)

object AppState {
    var counter = mutableStateOf(0)
    var inputText = mutableStateOf("")
    var checkboxChecked = mutableStateOf(false)
    var currentPage = mutableStateOf("home") // "home" or "detail"
    val logs = CopyOnWriteArrayList<String>()

    fun log(msg: String) {
        logs.add("[${System.currentTimeMillis()}] $msg")
    }

    fun getElements(): List<ElementInfo> {
        return if (currentPage.value == "home") {
            listOf(
                ElementInfo("counter", "Text", "Counter: ${counter.value}"),
                ElementInfo("increment-btn", "Button", "Increment"),
                ElementInfo("text-input", "TextField", inputText.value),
                ElementInfo("test-checkbox", "Checkbox", if (checkboxChecked.value) "checked" else "unchecked"),
                ElementInfo("detail-btn", "Button", "Go to Detail"),
                ElementInfo("submit-btn", "Button", "Submit"),
                ElementInfo("list_item_0", "Text", "Item 0"),
                ElementInfo("list_item_1", "Text", "Item 1"),
                ElementInfo("list_item_2", "Text", "Item 2"),
                ElementInfo("list_item_3", "Text", "Item 3"),
                ElementInfo("list_item_4", "Text", "Item 4"),
            )
        } else {
            listOf(
                ElementInfo("detail_title", "Text", "Detail Page"),
                ElementInfo("detail_content", "Text", "This is the detail page"),
                ElementInfo("back-btn", "Button", "Go Back"),
            )
        }
    }

    fun getInteractiveElements(): List<ElementInfo> {
        return getElements().filter {
            it.type in listOf("Button", "TextField", "Checkbox")
        }
    }

    fun findByKey(key: String): ElementInfo? = getElements().find { it.key == key }

    fun findByText(text: String): ElementInfo? = getElements().find { it.text.contains(text, ignoreCase = true) }

    fun performTap(key: String): Boolean {
        log("tap: $key")
        return when (key) {
            "increment-btn" -> { counter.value++; true }
            "detail-btn" -> { currentPage.value = "detail"; true }
            "back-btn" -> { currentPage.value = "home"; true }
            "test-checkbox" -> { checkboxChecked.value = !checkboxChecked.value; true }
            "submit-btn" -> { log("submit pressed"); true }
            else -> false
        }
    }

    fun performTapByText(text: String): Boolean {
        val el = findByText(text) ?: return false
        return performTap(el.key)
    }

    fun enterText(key: String, text: String): Boolean {
        log("enter_text: $key = $text")
        return when (key) {
            "text-input" -> { inputText.value = text; true }
            else -> false
        }
    }

    fun getText(key: String): String? {
        return when (key) {
            "counter" -> "Counter: ${counter.value}"
            "text-input" -> inputText.value
            else -> findByKey(key)?.text
        }
    }

    fun goBack(): Boolean {
        if (currentPage.value != "home") {
            currentPage.value = "home"
            log("go_back")
        } else {
            log("go_back (already home)")
        }
        return true
    }
}

// ─── Bridge Server ───

val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

@Serializable
data class RpcRequest(
    val jsonrpc: String = "2.0",
    val method: String,
    val params: JsonObject? = null,
    val id: JsonElement
)

@Serializable
data class RpcResponse(
    val jsonrpc: String = "2.0",
    val result: JsonElement? = null,
    val error: JsonElement? = null,
    val id: JsonElement
)

sealed class RpcResult {
    data class Success(val value: JsonElement) : RpcResult()
    data class Error(val code: Int, val message: String) : RpcResult()
}

fun handleRpc(req: RpcRequest): RpcResult {
    val p = req.params ?: buildJsonObject {}
    val key = p["key"]?.jsonPrimitive?.contentOrNull
    val text = p["text"]?.jsonPrimitive?.contentOrNull
    val selector = p["selector"]?.jsonPrimitive?.contentOrNull
    val ref = p["ref"]?.jsonPrimitive?.contentOrNull

    AppState.log("rpc: ${req.method}")

    return when (req.method) {
        "health" -> RpcResult.Success(buildJsonObject {
            put("status", "ok")
            put("platform", "kmp")
        })

        "initialize" -> RpcResult.Success(buildJsonObject {
            put("protocol_version", "1.0")
            put("platform", "kmp")
            put("capabilities", buildJsonArray {
                add("inspect"); add("inspect_interactive"); add("tap"); add("enter_text"); add("screenshot")
                add("scroll"); add("get_text"); add("find_element"); add("wait_for_element")
                add("go_back"); add("swipe"); add("get_logs"); add("clear_logs")
            })
        })

        "inspect" -> RpcResult.Success(buildJsonObject {
            put("elements", buildJsonArray {
                for (el in AppState.getElements()) {
                    add(buildJsonObject {
                        put("key", el.key)
                        put("type", el.type)
                        put("class", el.type)
                        put("text", el.text)
                        put("bounds", buildJsonObject {
                            for ((k, v) in el.bounds) put(k, v)
                        })
                    })
                }
            })
        })

        "inspect_interactive" -> {
            val refCounts = mutableMapOf<String, Int>()
            fun semanticRef(role: String, content: String?): String {
                val sanitized = content?.trim()
                    ?.replace(Regex("\\s+"), "_")
                    ?.replace(Regex("[^\\w]"), "")
                    ?.take(30)
                    ?.takeIf { it.isNotEmpty() }
                val base = if (sanitized != null) "$role:$sanitized" else role
                val count = refCounts[base] ?: 0
                refCounts[base] = count + 1
                return if (count == 0) base else "$base[$count]"
            }

            val elements = AppState.getInteractiveElements()
            RpcResult.Success(buildJsonObject {
                put("elements", buildJsonArray {
                    for (el in elements) {
                        val role = when (el.type) {
                            "Button" -> "button"
                            "TextField" -> "input"
                            "Checkbox" -> "toggle"
                            else -> "element"
                        }
                        val actions = when (role) {
                            "input" -> listOf("tap", "enter_text")
                            "toggle" -> listOf("tap")
                            else -> listOf("tap")
                        }
                        add(buildJsonObject {
                            put("ref", semanticRef(role, el.text))
                            put("type", el.type)
                            put("text", el.text)
                            put("enabled", el.enabled)
                            put("actions", buildJsonArray { actions.forEach { add(it) } })
                            put("bounds", buildJsonObject {
                                put("x", el.bounds["x"] ?: 0)
                                put("y", el.bounds["y"] ?: 0)
                                put("w", el.bounds["width"] ?: 100)
                                put("h", el.bounds["height"] ?: 30)
                            })
                        })
                    }
                })
                put("summary", "${elements.size} interactive elements found")
            })
        }

        "tap" -> {
            val success = if (ref != null) {
                // Tap by ref - find element from interactive list by matching ref
                val interactive = handleRpc(RpcRequest(method = "inspect_interactive", id = req.id))
                if (interactive is RpcResult.Success) {
                    val els = interactive.value.jsonObject["elements"]?.jsonArray
                    val target = els?.find { it.jsonObject["ref"]?.jsonPrimitive?.content == ref }
                    if (target != null) {
                        val elText = target.jsonObject["text"]?.jsonPrimitive?.contentOrNull
                        if (elText != null) AppState.performTapByText(elText) else false
                    } else false
                } else false
            } else if (key != null) {
                AppState.performTap(key)
            } else if (text != null) {
                AppState.performTapByText(text)
            } else if (selector != null) {
                AppState.performTap(selector)
            } else {
                // coordinate tap or no params
                val x = p["x"]?.jsonPrimitive?.intOrNull
                val y = p["y"]?.jsonPrimitive?.intOrNull
                if (x != null && y != null) {
                    AppState.log("tap at ($x, $y)")
                    true
                } else {
                    return RpcResult.Error(-32602, "tap requires key, text, ref, or coordinates")
                }
            }
            RpcResult.Success(buildJsonObject { put("success", success) })
        }

        "enter_text" -> {
            val k = key ?: selector ?: ""
            val t = text ?: p["value"]?.jsonPrimitive?.contentOrNull ?: ""
            RpcResult.Success(buildJsonObject { put("success", AppState.enterText(k, t)) })
        }

        "get_text" -> {
            val k = key ?: selector ?: ""
            val t = AppState.getText(k)
            RpcResult.Success(buildJsonObject {
                if (t != null) put("text", t) else put("error", "not found")
            })
        }

        "find_element" -> {
            val k = key ?: selector
            val found = if (k != null) AppState.findByKey(k) else if (text != null) AppState.findByText(text) else null
            RpcResult.Success(buildJsonObject {
                put("found", found != null)
                if (found != null) {
                    put("key", found.key)
                    put("type", found.type)
                    put("text", found.text)
                    put("bounds", buildJsonObject {
                        put("x", found.bounds["x"] ?: 0)
                        put("y", found.bounds["y"] ?: 0)
                        put("w", found.bounds["width"] ?: 100)
                        put("h", found.bounds["height"] ?: 30)
                    })
                }
            })
        }

        "wait_for_element" -> {
            val k = key ?: selector
            val timeout = p["timeout"]?.jsonPrimitive?.longOrNull ?: 5000L
            val start = System.currentTimeMillis()
            var found: ElementInfo? = null
            while (System.currentTimeMillis() - start < timeout) {
                found = if (k != null) AppState.findByKey(k) else if (text != null) AppState.findByText(text) else null
                if (found != null) break
                Thread.sleep(100)
            }
            RpcResult.Success(buildJsonObject {
                put("found", found != null)
            })
        }

        "scroll" -> {
            AppState.log("scroll: ${p["direction"]?.jsonPrimitive?.contentOrNull} ${p["distance"]?.jsonPrimitive?.contentOrNull}")
            RpcResult.Success(buildJsonObject { put("success", true) })
        }

        "swipe" -> {
            AppState.log("swipe: ${p["direction"]?.jsonPrimitive?.contentOrNull} ${p["distance"]?.jsonPrimitive?.contentOrNull}")
            RpcResult.Success(buildJsonObject { put("success", true) })
        }

        "screenshot" -> {
            val img = BufferedImage(100, 100, BufferedImage.TYPE_INT_RGB)
            val g = img.createGraphics()
            g.fillRect(0, 0, 100, 100)
            g.dispose()
            val baos = ByteArrayOutputStream()
            ImageIO.write(img, "png", baos)
            val b64 = java.util.Base64.getEncoder().encodeToString(baos.toByteArray())
            RpcResult.Success(buildJsonObject { put("image", b64); put("format", "png") })
        }

        "go_back" -> RpcResult.Success(buildJsonObject { put("success", AppState.goBack()) })

        "get_logs" -> RpcResult.Success(buildJsonObject {
            put("logs", buildJsonArray { for (l in AppState.logs) add(l) })
        })

        "clear_logs" -> {
            AppState.logs.clear()
            RpcResult.Success(buildJsonObject { put("success", true) })
        }

        "eval" -> RpcResult.Error(-32601, "eval not supported on kmp")

        else -> RpcResult.Error(-32601, "Method not found: ${req.method}")
    }
}

fun startBridgeServer(port: Int) {
    embeddedServer(CIO, port = port) {
        install(WebSockets)
        routing {
            // HTTP health endpoint
            get("/.flutter-skill") {
                call.respondText(
                    json.encodeToString(buildJsonObject {
                        put("status", "ok")
                        put("platform", "kmp")
                        put("framework", "compose-desktop")
                        put("sdk_version", "1.0.0")
                        put("capabilities", buildJsonArray {
                            add("inspect"); add("inspect_interactive"); add("tap"); add("enter_text"); add("screenshot")
                            add("scroll"); add("get_text"); add("find_element"); add("go_back")
                        })
                    }),
                    contentType = ContentType.Application.Json
                )
            }

            // WebSocket bridge
            webSocket("/ws") {
                println("[bridge] Client connected")
                for (frame in incoming) {
                    if (frame is Frame.Text) {
                        val raw = frame.readText()
                        val response = try {
                            val req = json.decodeFromString<RpcRequest>(raw)
                            val rpcResult = handleRpc(req)
                            when (rpcResult) {
                                is RpcResult.Success -> json.encodeToString(RpcResponse(result = rpcResult.value, id = req.id))
                                is RpcResult.Error -> json.encodeToString(RpcResponse(
                                    error = buildJsonObject { put("code", rpcResult.code); put("message", rpcResult.message) },
                                    id = req.id
                                ))
                            }
                        } catch (e: Exception) {
                            json.encodeToString(RpcResponse(
                                error = buildJsonObject { put("code", -32700); put("message", e.message ?: "error") },
                                id = JsonNull
                            ))
                        }
                        send(Frame.Text(response))
                    }
                }
                println("[bridge] Client disconnected")
            }
        }
    }.start(wait = false)
    println("[flutter-skill-kmp] Bridge server on port $port (HTTP + WS)")
}

// ─── Compose UI ───

@Composable
@Preview
fun HomePage() {
    val counter by AppState.counter
    val inputText by AppState.inputText
    val checked by AppState.checkboxChecked

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("KMP Test App - Home", style = MaterialTheme.typography.h5)
        Spacer(Modifier.height(16.dp))

        // Counter
        Text("Counter: $counter")
        Button(onClick = { AppState.counter.value++ }) {
            Text("Increment")
        }
        Spacer(Modifier.height(16.dp))

        // Text input
        OutlinedTextField(
            value = inputText,
            onValueChange = { AppState.inputText.value = it },
            label = { Text("Input") },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(16.dp))

        // Checkbox
        Row(verticalAlignment = Alignment.CenterVertically) {
            Checkbox(checked = checked, onCheckedChange = { AppState.checkboxChecked.value = it })
            Text("Toggle me")
        }
        Spacer(Modifier.height(16.dp))

        // Submit
        Button(onClick = { AppState.log("submit pressed") }) {
            Text("Submit")
        }
        Spacer(Modifier.height(16.dp))

        // Navigation
        Button(onClick = { AppState.currentPage.value = "detail" }) {
            Text("Go to Detail")
        }
        Spacer(Modifier.height(16.dp))

        // List items
        LazyColumn {
            items((0..4).toList()) { i ->
                Text("Item $i", modifier = Modifier.padding(8.dp))
            }
        }
    }
}

@Composable
@Preview
fun DetailPage() {
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("Detail Page", style = MaterialTheme.typography.h5)
        Spacer(Modifier.height(16.dp))
        Text("This is the detail page")
        Spacer(Modifier.height(16.dp))
        Button(onClick = { AppState.currentPage.value = "home" }) {
            Text("Go Back")
        }
    }
}

@Composable
@Preview
fun App() {
    val page by AppState.currentPage
    MaterialTheme {
        when (page) {
            "home" -> HomePage()
            "detail" -> DetailPage()
        }
    }
}

fun main() {
    // Start bridge server first
    startBridgeServer(18118)

    // Launch Compose Desktop window
    application {
        Window(onCloseRequest = ::exitApplication, title = "KMP Test App") {
            App()
        }
    }
}
