using System;
using System.Collections;
using Beefy;

namespace BeefyScope;

class Program
{
	public static int Main(String[] args)
	{
		Console.WriteLine("BSApp says hello!");

		BFApp.SetOption("SDL", "1");

		BSApp app = scope .();
		app.Init();
		app.Run();
		app.Shutdown();

		return 0;
	}
}