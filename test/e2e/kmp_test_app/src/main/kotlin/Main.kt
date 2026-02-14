import androidx.compose.desktop.ui.tooling.preview.Preview
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
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
    var currentPage = mutableStateOf("home") // "home", "detail", "search", "create", "profile"
    var currentTab = mutableStateOf("home")
    var searchQuery = mutableStateOf("")
    var switchToggled = mutableStateOf(false)
    var createTitle = mutableStateOf("")
    var createDescription = mutableStateOf("")
    var createDropdownExpanded = mutableStateOf(false)
    var createDropdownSelection = mutableStateOf("General")
    var createCheckbox = mutableStateOf(false)
    var createSwitch = mutableStateOf(false)
    var showSettingsDialog = mutableStateOf(false)
    var settingsNotifications = mutableStateOf(true)
    var settingsDarkMode = mutableStateOf(false)
    var snackbarMessage = mutableStateOf("")
    val logs = CopyOnWriteArrayList<String>()

    fun log(msg: String) {
        logs.add("[${System.currentTimeMillis()}] $msg")
    }

    fun getElements(): List<ElementInfo> {
        return when (currentPage.value) {
            "detail" -> listOf(
                ElementInfo("detail_title", "Text", "Detail Page"),
                ElementInfo("detail_content", "Text", "This is the detail page with extended content about the selected post."),
                ElementInfo("back-btn", "Button", "Go Back"),
            )
            else -> {
                val common = mutableListOf(
                    ElementInfo("tab-home", "Button", "Home"),
                    ElementInfo("tab-search", "Button", "Search"),
                    ElementInfo("tab-create", "Button", "Create"),
                    ElementInfo("tab-profile", "Button", "Profile"),
                )
                // Always include backward-compat elements regardless of tab
                common.add(ElementInfo("counter", "Text", "Counter: ${counter.value}"))
                common.add(ElementInfo("increment-btn", "Button", "Increment"))
                common.add(ElementInfo("text-input", "TextField", inputText.value))
                common.add(ElementInfo("test-checkbox", "Checkbox", if (checkboxChecked.value) "checked" else "unchecked"))
                common.add(ElementInfo("detail-btn", "Button", "Go to Detail"))
                common.add(ElementInfo("submit-btn", "Button", "Submit"))

                when (currentTab.value) {
                    "home" -> {
                        for (i in 0 until 20) {
                            common.add(ElementInfo("feed-item-$i", "Card", "Post #$i - Amazing content about topic $i"))
                        }
                        // 50+ list items for scrolling
                        for (i in 0 until 50) {
                            common.add(ElementInfo("list_item_$i", "Text", "Item $i"))
                        }
                    }
                    "search" -> {
                        common.add(ElementInfo("search-input", "TextField", searchQuery.value))
                        common.add(ElementInfo("toggle-switch", "Switch", if (switchToggled.value) "on" else "off"))
                        for (i in 0 until 10) {
                            common.add(ElementInfo("search_result_$i", "Text", "Result $i for '${searchQuery.value}'"))
                        }
                    }
                    "create" -> {
                        common.add(ElementInfo("create-title", "TextField", createTitle.value))
                        common.add(ElementInfo("create-description", "TextField", createDescription.value))
                        common.add(ElementInfo("toggle-switch", "Switch", if (createSwitch.value) "on" else "off"))
                    }
                    "profile" -> {
                        common.add(ElementInfo("settings-btn", "Button", "Settings"))
                        common.add(ElementInfo("profile_name", "Text", "John Doe"))
                        common.add(ElementInfo("profile_stats", "Text", "42 Posts | 1.2K Followers | 500 Following"))
                        for (i in 0 until 10) {
                            common.add(ElementInfo("profile_post_$i", "Text", "My post #$i"))
                        }
                    }
                }
                common
            }
        }
    }

    fun getInteractiveElements(): List<ElementInfo> {
        return getElements().filter {
            it.type in listOf("Button", "TextField", "Checkbox", "Switch")
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
            "submit-btn" -> { snackbarMessage.value = "Form submitted!"; log("submit pressed"); true }
            "tab-home" -> { currentTab.value = "home"; currentPage.value = "home"; true }
            "tab-search" -> { currentTab.value = "search"; currentPage.value = "home"; true }
            "tab-create" -> { currentTab.value = "create"; currentPage.value = "home"; true }
            "tab-profile" -> { currentTab.value = "profile"; currentPage.value = "home"; true }
            "settings-btn" -> { showSettingsDialog.value = true; true }
            "toggle-switch" -> {
                if (currentTab.value == "search") { switchToggled.value = !switchToggled.value }
                else { createSwitch.value = !createSwitch.value }
                true
            }
            else -> {
                // Handle feed-item clicks
                if (key.startsWith("feed-item-")) { currentPage.value = "detail"; true }
                else false
            }
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
            "search-input" -> { searchQuery.value = text; true }
            "create-title" -> { createTitle.value = text; true }
            "create-description" -> { createDescription.value = text; true }
            else -> false
        }
    }

    fun getText(key: String): String? {
        return when (key) {
            "counter" -> "Counter: ${counter.value}"
            "text-input" -> inputText.value
            "search-input" -> searchQuery.value
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
                            "Switch" -> "toggle"
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
            get("/.flutter-skill") {
                call.respondText(
                    json.encodeToString(buildJsonObject {
                        put("status", "ok")
                        put("platform", "kmp")
                        put("framework", "compose-desktop")
                        put("sdk_version", "1.0.0")
                        put("capabilities", buildJsonArray {
                            add("inspect"); add("inspect_interactive"); add("tap"); add("enter_text"); add("screenshot")
                            add("scroll"); add("get_text"); add("find_element"); add("wait_for_element")
                            add("go_back"); add("swipe"); add("get_logs"); add("clear_logs")
                        })
                    }),
                    contentType = ContentType.Application.Json
                )
            }

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
fun FeedCard(index: Int, onCardClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 4.dp)
            .testTag("feed-item-$index")
            .clickable { onCardClick() },
        elevation = 2.dp
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Text("Post #$index", style = MaterialTheme.typography.h6)
            Spacer(Modifier.height(4.dp))
            Text("Amazing content about topic $index", style = MaterialTheme.typography.body2, color = MaterialTheme.colors.onSurface.copy(alpha = 0.7f))
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = {}) {
                    Icon(Icons.Default.Favorite, contentDescription = "Like")
                }
                Text("${(index * 7 + 3) % 100}", style = MaterialTheme.typography.caption)
                Spacer(Modifier.width(16.dp))
                Icon(Icons.Default.Email, contentDescription = "Comments", modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(4.dp))
                Text("${(index * 3 + 1) % 50} comments", style = MaterialTheme.typography.caption)
            }
        }
    }
}

@Composable
fun HomeTab() {
    val counter by AppState.counter

    LazyColumn(modifier = Modifier.fillMaxSize()) {
        item {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("Counter: $counter", modifier = Modifier.testTag("counter"))
                Spacer(Modifier.height(8.dp))
                Button(
                    onClick = { AppState.counter.value++ },
                    modifier = Modifier.testTag("increment-btn")
                ) { Text("Increment") }
            }
        }

        items(20) { i ->
            FeedCard(i) { AppState.currentPage.value = "detail" }
        }

        item {
            Button(
                onClick = { AppState.currentPage.value = "detail" },
                modifier = Modifier.padding(16.dp).testTag("detail-btn")
            ) { Text("Go to Detail") }
        }

        // Long scrollable list (50+ items)
        items(50) { i ->
            Text("Item $i", modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp).testTag("list_item_$i"))
        }
    }
}

@Composable
fun SearchTab() {
    val searchQuery by AppState.searchQuery
    val inputText by AppState.inputText
    val toggled by AppState.switchToggled

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("Search", style = MaterialTheme.typography.h5)
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = searchQuery,
            onValueChange = { AppState.searchQuery.value = it },
            label = { Text("Search...") },
            modifier = Modifier.fillMaxWidth().testTag("search-input")
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = inputText,
            onValueChange = { AppState.inputText.value = it },
            label = { Text("Input") },
            modifier = Modifier.fillMaxWidth().testTag("text-input")
        )
        Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Filter active")
            Spacer(Modifier.width(8.dp))
            Switch(
                checked = toggled,
                onCheckedChange = { AppState.switchToggled.value = it },
                modifier = Modifier.testTag("toggle-switch")
            )
        }
        Spacer(Modifier.height(12.dp))
        LazyColumn {
            items(10) { i ->
                Text("Result $i for '$searchQuery'", modifier = Modifier.padding(8.dp))
            }
        }
    }
}

@Composable
fun CreateTab() {
    val inputText by AppState.inputText
    val checked by AppState.checkboxChecked
    val createSwitch by AppState.createSwitch
    val createTitle by AppState.createTitle
    val createDesc by AppState.createDescription
    val scaffoldState = rememberScaffoldState()
    val scope = rememberCoroutineScope()

    Scaffold(scaffoldState = scaffoldState) {
        Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            Text("Create Post", style = MaterialTheme.typography.h5)
            Spacer(Modifier.height(12.dp))

            OutlinedTextField(
                value = inputText,
                onValueChange = { AppState.inputText.value = it },
                label = { Text("Input") },
                modifier = Modifier.fillMaxWidth().testTag("text-input")
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = createTitle,
                onValueChange = { AppState.createTitle.value = it },
                label = { Text("Title") },
                modifier = Modifier.fillMaxWidth().testTag("create-title")
            )
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = createDesc,
                onValueChange = { AppState.createDescription.value = it },
                label = { Text("Description") },
                modifier = Modifier.fillMaxWidth().testTag("create-description"),
                maxLines = 4
            )
            Spacer(Modifier.height(8.dp))

            // Dropdown
            Box {
                var expanded by remember { mutableStateOf(false) }
                OutlinedButton(onClick = { expanded = true }) {
                    Text("Category: ${AppState.createDropdownSelection.value}")
                }
                DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    listOf("General", "Tech", "Art", "Music").forEach { cat ->
                        DropdownMenuItem(onClick = { AppState.createDropdownSelection.value = cat; expanded = false }) {
                            Text(cat)
                        }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Checkbox(
                    checked = checked,
                    onCheckedChange = { AppState.checkboxChecked.value = it },
                    modifier = Modifier.testTag("test-checkbox")
                )
                Text("I agree to terms")
            }
            Spacer(Modifier.height(8.dp))

            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Publish immediately")
                Spacer(Modifier.width(8.dp))
                Switch(
                    checked = createSwitch,
                    onCheckedChange = { AppState.createSwitch.value = it },
                    modifier = Modifier.testTag("toggle-switch")
                )
            }
            Spacer(Modifier.height(16.dp))

            Button(
                onClick = {
                    AppState.snackbarMessage.value = "Form submitted!"
                    AppState.log("submit pressed")
                    scope.launch {
                        scaffoldState.snackbarHostState.showSnackbar("Post created successfully!")
                    }
                },
                modifier = Modifier.testTag("submit-btn")
            ) { Text("Submit") }
        }
    }
}

@Composable
fun ProfileTab() {
    val showDialog by AppState.showSettingsDialog
    val notif by AppState.settingsNotifications
    val dark by AppState.settingsDarkMode

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Text("Profile", style = MaterialTheme.typography.h5)
        Spacer(Modifier.height(12.dp))
        Text("John Doe", style = MaterialTheme.typography.h6)
        Text("@johndoe", style = MaterialTheme.typography.caption)
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.fillMaxWidth()) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) { Text("42", style = MaterialTheme.typography.h6); Text("Posts") }
            Column(horizontalAlignment = Alignment.CenterHorizontally) { Text("1.2K", style = MaterialTheme.typography.h6); Text("Followers") }
            Column(horizontalAlignment = Alignment.CenterHorizontally) { Text("500", style = MaterialTheme.typography.h6); Text("Following") }
        }
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = { AppState.showSettingsDialog.value = true },
            modifier = Modifier.testTag("settings-btn")
        ) {
            Icon(Icons.Default.Settings, contentDescription = null)
            Spacer(Modifier.width(4.dp))
            Text("Settings")
        }
        Spacer(Modifier.height(12.dp))
        LazyColumn {
            items(10) { i ->
                Card(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Text("My post #$i", modifier = Modifier.padding(12.dp))
                }
            }
        }
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { AppState.showSettingsDialog.value = false },
            title = { Text("Settings") },
            text = {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Notifications", modifier = Modifier.weight(1f))
                        Switch(checked = notif, onCheckedChange = { AppState.settingsNotifications.value = it })
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Dark Mode", modifier = Modifier.weight(1f))
                        Switch(checked = dark, onCheckedChange = { AppState.settingsDarkMode.value = it })
                    }
                }
            },
            confirmButton = {
                Button(onClick = { AppState.showSettingsDialog.value = false }) { Text("Done") }
            }
        )
    }
}

@Composable
fun DetailPage() {
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        Button(onClick = { AppState.currentPage.value = "home" }) {
            Icon(Icons.Default.ArrowBack, contentDescription = null)
            Spacer(Modifier.width(4.dp))
            Text("Go Back")
        }
        Spacer(Modifier.height(16.dp))
        Text("Detail Page", style = MaterialTheme.typography.h5)
        Spacer(Modifier.height(8.dp))
        Text("This is the detail page with extended content about the selected post.")
        Spacer(Modifier.height(16.dp))
        Text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
    }
}

@Composable
@Preview
fun App() {
    val page by AppState.currentPage
    val tab by AppState.currentTab

    MaterialTheme {
        when (page) {
            "detail" -> DetailPage()
            else -> {
                Column(modifier = Modifier.fillMaxSize()) {
                    // Tab bar
                    TabRow(selectedTabIndex = listOf("home", "search", "create", "profile").indexOf(tab)) {
                        Tab(selected = tab == "home", onClick = { AppState.currentTab.value = "home" }, modifier = Modifier.testTag("tab-home")) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(8.dp)) {
                                Icon(Icons.Default.Home, contentDescription = null)
                                Text("Home")
                            }
                        }
                        Tab(selected = tab == "search", onClick = { AppState.currentTab.value = "search" }, modifier = Modifier.testTag("tab-search")) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(8.dp)) {
                                Icon(Icons.Default.Search, contentDescription = null)
                                Text("Search")
                            }
                        }
                        Tab(selected = tab == "create", onClick = { AppState.currentTab.value = "create" }, modifier = Modifier.testTag("tab-create")) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(8.dp)) {
                                Icon(Icons.Default.Add, contentDescription = null)
                                Text("Create")
                            }
                        }
                        Tab(selected = tab == "profile", onClick = { AppState.currentTab.value = "profile" }, modifier = Modifier.testTag("tab-profile")) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(8.dp)) {
                                Icon(Icons.Default.Person, contentDescription = null)
                                Text("Profile")
                            }
                        }
                    }

                    // Tab content
                    when (tab) {
                        "home" -> HomeTab()
                        "search" -> SearchTab()
                        "create" -> CreateTab()
                        "profile" -> ProfileTab()
                    }
                }
            }
        }
    }
}

fun main() {
    startBridgeServer(18118)
    application {
        Window(onCloseRequest = ::exitApplication, title = "KMP Test App") {
            App()
        }
    }
}
