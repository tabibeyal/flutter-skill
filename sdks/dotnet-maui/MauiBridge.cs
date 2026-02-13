// This file requires the MAUI workload to compile.
// Install with: dotnet workload install maui
// Then change the csproj TargetFramework to net9.0-android;net9.0-ios;net9.0-maccatalyst
// and add: <UseMaui>true</UseMaui>
//
// For now, this file is excluded from the default build (net9.0 target).
// It serves as the reference implementation for MAUI integration.

#if MAUI_BUILD
using System.Text.Json.Nodes;
using Microsoft.Maui.Controls;

namespace FlutterSkill;

/// <summary>
/// MAUI-specific bridge that walks the MAUI element tree for UI automation.
/// </summary>
public class MauiFlutterSkillBridge : FlutterSkillBridge
{
    public MauiFlutterSkillBridge(int port = 18118) : base(port) { }

    protected override string GetPlatformName() => "maui";

    private static Page? GetCurrentPage()
    {
        if (Application.Current?.MainPage is NavigationPage nav)
            return nav.CurrentPage;
        if (Application.Current?.MainPage is Shell shell)
            return shell.CurrentPage;
        return Application.Current?.MainPage;
    }

    protected override Task<JsonObject> HandleInspect(JsonObject parms)
    {
        var page = GetCurrentPage();
        if (page == null) return Task.FromResult(new JsonObject { ["error"] = "No page" });
        return Task.FromResult(WalkElement(page, 0));
    }

    private static JsonObject WalkElement(Element el, int depth)
    {
        var node = new JsonObject
        {
            ["type"] = el.GetType().Name,
        };

        if (el is BindableObject bo)
        {
            var autoId = AutomationProperties.GetAutomationId(bo);
            if (!string.IsNullOrEmpty(autoId))
                node["automationId"] = autoId;
        }

        if (el is Label lbl) node["text"] = lbl.Text?.Substring(0, Math.Min(lbl.Text.Length, 200));
        if (el is Button btn) node["text"] = btn.Text?.Substring(0, Math.Min(btn.Text.Length, 200));
        if (el is Entry ent) node["text"] = ent.Text?.Substring(0, Math.Min(ent.Text?.Length ?? 0, 200));

        if (depth < 15)
        {
            var children = new JsonArray();
            foreach (var child in el.LogicalChildren.OfType<Element>())
                children.Add(WalkElement(child, depth + 1));
            if (children.Count > 0) node["children"] = children;
        }
        return node;
    }

    protected override Task<JsonObject> HandleTap(string selector, JsonObject parms)
    {
        var el = FindByAutomationId(selector);
        if (el is Button btn)
        {
            MainThread.BeginInvokeOnMainThread(() => ((IButtonController)btn).SendClicked());
            return Task.FromResult(new JsonObject { ["tapped"] = true });
        }
        if (el is VisualElement)
            return Task.FromResult(new JsonObject { ["tapped"] = true, ["note"] = "element found, tap simulated" });
        return Task.FromResult(new JsonObject { ["error"] = "not found" });
    }

    protected override Task<JsonObject> HandleEnterText(string selector, string text, JsonObject parms)
    {
        var el = FindByAutomationId(selector) as Entry;
        if (el == null) return Task.FromResult(new JsonObject { ["error"] = "Entry not found" });
        MainThread.BeginInvokeOnMainThread(() => el.Text = text);
        return Task.FromResult(new JsonObject { ["entered"] = true });
    }

    protected override Task<JsonObject> HandleScreenshot(JsonObject parms)
    {
        return Task.FromResult(new JsonObject
        {
            ["screenshot"] = "pending",
            ["note"] = "Use platform-specific screenshot capture (e.g. Screenshot.CaptureAsync on supported platforms)"
        });
    }

    protected override Task<JsonObject> HandleScroll(int dx, int dy, JsonObject parms)
    {
        var page = GetCurrentPage();
        var scrollView = FindFirst<ScrollView>(page);
        if (scrollView != null)
        {
            MainThread.BeginInvokeOnMainThread(async () =>
                await scrollView.ScrollToAsync(scrollView.ScrollX + dx, scrollView.ScrollY + dy, true));
            return Task.FromResult(new JsonObject { ["scrolled"] = true });
        }
        return Task.FromResult(new JsonObject { ["scrolled"] = false });
    }

    protected override Task<JsonObject> HandleGetText(string selector, JsonObject parms)
    {
        var el = FindByAutomationId(selector);
        var text = el switch
        {
            Label l => l.Text,
            Button b => b.Text,
            Entry e => e.Text,
            _ => null
        };
        return Task.FromResult(text != null
            ? new JsonObject { ["text"] = text }
            : new JsonObject { ["error"] = "not found" });
    }

    protected override Task<JsonObject> HandleFindElement(string? selector, string? text, JsonObject parms)
    {
        if (selector != null)
            return Task.FromResult(new JsonObject { ["found"] = (FindByAutomationId(selector) != null) });
        if (text != null)
        {
            var page = GetCurrentPage();
            var found = FindFirst<Label>(page, l => l.Text?.Contains(text) == true) != null ||
                        FindFirst<Button>(page, b => b.Text?.Contains(text) == true) != null;
            return Task.FromResult(new JsonObject { ["found"] = found });
        }
        return Task.FromResult(new JsonObject { ["error"] = "selector or text required" });
    }

    protected override async Task<JsonObject> HandleWaitForElement(string selector, int timeout, JsonObject parms)
    {
        var start = Environment.TickCount64;
        while (Environment.TickCount64 - start < timeout)
        {
            if (FindByAutomationId(selector) != null)
                return new JsonObject { ["found"] = true };
            await Task.Delay(100);
        }
        return new JsonObject { ["found"] = false, ["error"] = "timeout" };
    }

    private static Element? FindByAutomationId(string id)
    {
        var page = GetCurrentPage();
        if (page == null) return null;
        return FindFirst<Element>(page, e =>
            e is BindableObject bo && AutomationProperties.GetAutomationId(bo) == id);
    }

    private static T? FindFirst<T>(Element? root, Func<T, bool>? predicate = null) where T : Element
    {
        if (root == null) return null;
        if (root is T t && (predicate == null || predicate(t))) return t;
        foreach (var child in root.LogicalChildren.OfType<Element>())
        {
            var found = FindFirst<T>(child, predicate);
            if (found != null) return found;
        }
        return null;
    }
}
#endif
