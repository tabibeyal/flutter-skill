// Quick test runner — run with: dotnet run
namespace FlutterSkill;

public class Program
{
    public static async Task Main(string[] args)
    {
        var bridge = new FlutterSkillBridge(18119);
        bridge.Start();
        Console.WriteLine("Bridge started on port 18119. Press Enter to stop.");
        
        // Keep running for 30 seconds max (for automated testing)
        await Task.Delay(30000);
        bridge.Stop();
    }
}
