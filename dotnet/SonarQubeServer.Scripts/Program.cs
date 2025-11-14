using System;
using System.Diagnostics;
using System.IO;

namespace SonarQubeServer.Scripts
{

    class BackgroundTask
    {
        DateTime SubmittedAt { get; set; }
        DateTime StartedAt { get; set; }
        DateTime ExecutedAt { get; set; }
        int ExecutionTimeMs { get; set; }

    }

    static class Program
    {
        static void Main(string[] args)
        {
            Stopwatch stopWatch = new();
            stopWatch.Start();

            Console.WriteLine("Hello, SonarQube Server Scripts!");
            LoadBackgroundTaskData(args[0]);

            // Stopwatch stop and print elapsed time
            stopWatch.Stop();
            TimeSpan ts = stopWatch.Elapsed;
            string elapsedTime = String.Format("{0:00}:{1:00}:{2:00}.{3:00}",
                ts.Hours, ts.Minutes, ts.Seconds,
                ts.Milliseconds / 10);
            Console.WriteLine("RunTime " + elapsedTime);
        }

        private static void LoadBackgroundTaskData(string inputFileDirectoryPath)
        {
            string directoryPath = inputFileDirectoryPath;
            string[] files = Directory.GetFiles(directoryPath, "*.json");
        }
    }
}