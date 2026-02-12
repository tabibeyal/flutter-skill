package com.flutterskill

import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.core.view.children

/**
 * View hierarchy traversal and element descriptor builder.
 *
 * Walks the Android View tree starting from any root (typically DecorView)
 * and produces structured element descriptors compatible with the
 * flutter-skill bridge protocol.
 */
object ViewTraversal {

    /**
     * Interactive view class names that are always included in inspect results.
     * Checked via simple class name matching to avoid import dependencies.
     */
    private val INTERACTIVE_CLASS_NAMES = setOf(
        "Button", "ImageButton", "FloatingActionButton",
        "MaterialButton", "ExtendedFloatingActionButton",
        "EditText", "TextInputEditText", "AutoCompleteTextView",
        "CheckBox", "RadioButton", "Switch", "SwitchCompat",
        "ToggleButton", "CompoundButton",
        "Spinner", "SeekBar", "RatingBar",
        "ImageView", "CardView",
        "Chip", "ChipGroup",
        "NavigationBarItemView", "BottomNavigationItemView",
        "TabLayout", "TabItem",
    )

    /**
     * Walk the entire view hierarchy from [root] and return descriptors
     * for all interactive (tappable, editable, checkable) views.
     *
     * @param root          The root view to start traversal from.
     * @param interactiveOnly If true, only return interactive elements.
     * @return List of element descriptor maps.
     */
    fun collectElements(root: View, interactiveOnly: Boolean = true): List<Map<String, Any?>> {
        val elements = mutableListOf<Map<String, Any?>>()
        walkView(root, elements, interactiveOnly, depth = 0)
        return elements
    }

    /**
     * Recursively walk a view and its children, collecting element descriptors.
     */
    private fun walkView(
        view: View,
        elements: MutableList<Map<String, Any?>>,
        interactiveOnly: Boolean,
        depth: Int
    ) {
        // Skip invisible views entirely
        if (view.visibility != View.VISIBLE) return

        val isInteractive = isInteractiveView(view)

        if (!interactiveOnly || isInteractive) {
            elements.add(describeView(view, depth))
        }

        // Recurse into children
        if (view is ViewGroup) {
            for (child in view.children) {
                walkView(child, elements, interactiveOnly, depth + 1)
            }
        }
    }

    /**
     * Determine if a view is considered interactive (clickable, editable, etc.)
     */
    private fun isInteractiveView(view: View): Boolean {
        // Clickable or long-clickable views
        if (view.isClickable || view.isLongClickable) return true

        // Focusable input views
        if (view.isFocusable && view is EditText) return true

        // Check by class name for known interactive widget types
        val simpleName = view.javaClass.simpleName
        if (simpleName in INTERACTIVE_CLASS_NAMES) return true

        // Views with content descriptions are often interactive accessibility targets
        if (view.contentDescription != null && view.isClickable) return true

        // Views with explicit string tags set by the developer
        if (view.tag is String) return true

        return false
    }

    /**
     * Build a structured descriptor map for a single view.
     * Matches the bridge protocol element format.
     */
    fun describeView(view: View, depth: Int = 0): Map<String, Any?> {
        val location = IntArray(2)
        view.getLocationOnScreen(location)

        val className = view.javaClass.simpleName

        return mapOf(
            "type" to mapViewType(view, className),
            "class" to className,
            "id" to getViewResourceId(view),
            "tag" to view.tag?.toString(),
            "text" to extractText(view),
            "content_description" to view.contentDescription?.toString(),
            "bounds" to mapOf(
                "x" to location[0],
                "y" to location[1],
                "width" to view.width,
                "height" to view.height,
            ),
            "visible" to (view.visibility == View.VISIBLE),
            "enabled" to view.isEnabled,
            "clickable" to view.isClickable,
            "focusable" to view.isFocusable,
            "depth" to depth,
        )
    }

    /**
     * Map a view to a semantic type string for the bridge protocol.
     */
    private fun mapViewType(view: View, className: String): String = when {
        view is EditText -> "text_field"
        view is CheckBox -> "checkbox"
        view is RadioButton -> "radio"
        view is Switch -> "switch"
        view is ToggleButton -> "toggle"
        view is Button -> "button"
        view is ImageButton -> "button"
        view is SeekBar -> "slider"
        view is RatingBar -> "rating"
        view is Spinner -> "dropdown"
        view is ImageView -> "image"
        view is TextView -> "text"
        view is ScrollView || view is HorizontalScrollView -> "scroll_view"
        className.contains("RecyclerView") -> "list"
        className.contains("FloatingActionButton") -> "button"
        className.contains("Chip") -> "chip"
        className.contains("Card") -> "card"
        className.contains("Tab") -> "tab"
        view.isClickable -> "clickable"
        else -> "view"
    }

    /**
     * Extract the Android resource ID name (e.g. "btn_submit") for a view.
     * Returns null if no ID is set or the ID is system-internal.
     */
    private fun getViewResourceId(view: View): String? {
        if (view.id == View.NO_ID) return null
        return try {
            val name = view.resources.getResourceEntryName(view.id)
            name
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Extract text content from a view, handling various view types.
     */
    fun extractText(view: View): String? = when (view) {
        is ToggleButton -> if (view.isChecked) view.textOn?.toString() else view.textOff?.toString()
        is EditText -> view.text?.toString()
        is Button -> view.text?.toString()
        is TextView -> view.text?.toString()
        else -> null
    }

    /**
     * Find a single view by key. Searches by:
     * 1. View tag (exact match)
     * 2. Content description (exact match)
     * 3. Resource ID name (exact match)
     * 4. Visible text content (contains match)
     *
     * @param root The root view to search from.
     * @param key  The key to search for.
     * @return The first matching view, or null.
     */
    fun findByKey(root: View, key: String): View? {
        // 1. Tag match
        val byTag = root.findViewWithTag<View>(key)
        if (byTag != null) return byTag

        // 2. Walk for contentDescription, resource ID, or text
        return walkToFind(root, key)
    }

    /**
     * Walk the view tree searching for a view matching the key.
     */
    private fun walkToFind(view: View, key: String): View? {
        if (view.visibility != View.VISIBLE) return null

        // Content description
        if (view.contentDescription?.toString() == key) return view

        // Resource ID name
        if (view.id != View.NO_ID) {
            try {
                val name = view.resources.getResourceEntryName(view.id)
                if (name == key) return view
            } catch (_: Exception) {
                // ID not in resources
            }
        }

        // Text content (for TextView, Button, EditText, etc.)
        val text = extractText(view)
        if (text != null && text.contains(key)) return view

        // Recurse into children
        if (view is ViewGroup) {
            for (child in view.children) {
                val found = walkToFind(child, key)
                if (found != null) return found
            }
        }

        return null
    }
}
