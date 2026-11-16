using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

internal static class BrassAetherLauncher
{
    private const string GameName = "Brass & Aether";
    private const string GameExe = GameName + ".exe";
    private static readonly string State = AppDomain.CurrentDomain.BaseDirectory;

    [DllImport("user32.dll")]
    private static extern bool IsIconic(IntPtr window);

    [DllImport("user32.dll")]
    private static extern bool ShowWindowAsync(IntPtr window, int command);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr window);

    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        using (var mutex = new Mutex(false, @"Local\BrassAether.GameLauncher"))
        {
            bool acquired;
            try { acquired = mutex.WaitOne(0); }
            catch (AbandonedMutexException) { acquired = true; }
            if (!acquired) return;

            try
            {
                Log("Desktop launcher opened.");
                if (FocusRunningGame())
                    return;

                // Windows may lock the executable while the game is running.
                using (var update = StartUpdate())
                {
                    if (update != null)
                    {
                        WaitForUpdate(update);
                        if (update.ExitCode != 0)
                            Log("Update check exited with code " + update.ExitCode + ".");
                    }
                }
                if (!StartCachedGame())
                    ShowError("No playable build could be opened. Details are in " +
                        Path.Combine(State, "startup.log") + " and launcher.log.");
            }
            catch (Exception error)
            {
                Log(error.Message);
                ShowError(error.Message);
            }
            finally
            {
                mutex.ReleaseMutex();
            }
        }
    }

    private static bool FocusRunningGame()
    {
        var candidates = Process.GetProcessesByName(GameName);
        try
        {
            int session = Process.GetCurrentProcess().SessionId;
            foreach (var game in candidates)
            {
                if (game.HasExited || game.SessionId != session)
                    continue;
                var window = game.MainWindowHandle;
                if (window == IntPtr.Zero) continue;
                if (IsIconic(window)) ShowWindowAsync(window, 9); // SW_RESTORE
                SetForegroundWindow(window);
                return true;
            }
            return false;
        }
        finally
        {
            foreach (var game in candidates) game.Dispose();
        }
    }

    private static IEnumerable<string> CachedBuilds()
    {
        yield return Path.Combine(State, GameExe);
        // Support legacy installations until the updater can migrate the cached build.
        foreach (string marker in new[] { "current-build.txt", "current-build.previous" })
        {
            string path = Path.Combine(State, marker);
            if (!File.Exists(path)) continue;
            string revision;
            using (var file = new FileStream(path, FileMode.Open, FileAccess.Read,
                FileShare.ReadWrite | FileShare.Delete))
            using (var reader = new StreamReader(file))
                revision = reader.ReadToEnd().Trim();
            if (Regex.IsMatch(revision, @"\A[0-9a-f]{40}\z"))
                yield return Path.Combine(State, "builds", revision, GameExe);
        }
        yield return Path.Combine(State, "builds", "local", GameExe);
    }

    private static bool StartCachedGame()
    {
        var attempted = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (string path in CachedBuilds())
        {
            if (!File.Exists(path) || !attempted.Add(path)) continue;
            try
            {
                using (var game = Process.Start(new ProcessStartInfo(path)
                {
                    WorkingDirectory = Path.GetDirectoryName(path),
                    UseShellExecute = false
                }))
                {
                    if (!game.WaitForExit(900))
                    {
                        Log("Started " + path);
                        return true;
                    }
                    Log(path + " exited during startup (code " + game.ExitCode + ").");
                }
            }
            catch (Exception error)
            {
                Log(path + " could not start: " + error.Message);
            }
        }
        return false;
    }

    private static Process StartUpdate()
    {
        try
        {
            string powershell = Path.Combine(Environment.SystemDirectory,
                @"WindowsPowerShell\v1.0\powershell.exe");
            string script = Path.Combine(State, "Launch-BrassAether.ps1");
            return Process.Start(new ProcessStartInfo(powershell,
                "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned " +
                "-File \"" + script + "\" -CheckOnly -StateDirectory \"" +
                State.TrimEnd(Path.DirectorySeparatorChar) + "\"")
            {
                WorkingDirectory = State,
                CreateNoWindow = true,
                UseShellExecute = false
            });
        }
        catch (Exception error)
        {
            Log("Update check could not start: " + error.Message);
            return null;
        }
    }

    private static void WaitForUpdate(Process update)
    {
        if (update.WaitForExit(750)) return;
        using (var notice = new Form
        {
            Text = GameName,
            Width = 430,
            Height = 120,
            StartPosition = FormStartPosition.CenterScreen,
            FormBorderStyle = FormBorderStyle.FixedDialog,
            ControlBox = false
        })
        using (var timer = new System.Windows.Forms.Timer { Interval = 250 })
        {
            notice.Controls.Add(new Label
            {
                Text = "Checking for a game update...",
                Dock = DockStyle.Fill,
                TextAlign = System.Drawing.ContentAlignment.MiddleCenter
            });
            timer.Tick += delegate { if (update.HasExited) notice.Close(); };
            timer.Start();
            notice.ShowDialog();
        }
    }

    private static void Log(string line)
    {
        try { File.AppendAllText(Path.Combine(State, "startup.log"), DateTime.Now.ToString("o") + " " + line + Environment.NewLine); }
        catch (IOException) { }
        catch (UnauthorizedAccessException) { }
    }

    private static void ShowError(string message)
    {
        MessageBox.Show(message, GameName, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
