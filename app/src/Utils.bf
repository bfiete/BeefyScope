using System;
using Beefy.geom;
using Beefy.gfx;

namespace BeefyScope;

class Utils
{
	public static void TimeToStr(double time, String outStr)
	{
		if (time == 0)
		{
			outStr.Append("0s");
			return;
		}

		var time;
		if (time < 0)
		{
			time = -time;
			outStr.Append("-");
		}

		void HandleTime(double divisor, String unit)
		{
			double ut = time / divisor;
			if (Math.Abs(ut - (int)ut) < 0.0001)
				((int)ut).ToString(outStr);
			else
				ut.ToString(outStr);
			outStr.Append(unit);
		}

		if (time >= 1000)
		{
			HandleTime(1000, "ks");
			return;
		}

		if (time >= 1)
		{
			HandleTime(1, "s");
			return;
		}

		/*if (time >= 0.001)
		{
			HandleTime(0.001, "ms");
			return;
		}*/

		if (time >= 0.001)
		{
			HandleTime(0.001, "ms");
			return;
		}

		if (time >= 0.000001)
		{
			HandleTime(0.000001, "µs");
			return;
		}

		HandleTime(0.000000001, "ns");
	}

	public static void DrawLine(Graphics g, Vector2 start, Vector2 end, float width, uint32 color)
	{
		//g.DrawQuad
		
		/*float 
		

		Graphics.[Friend]Gfx_AllocTris(image.mNativeTextureSegment, 6);
		Graphics.[Friend]Gfx_SetDrawVertex(0, m.tx, m.ty, 0, u1, v1, mColor);
		Graphics.[Friend]Gfx_SetDrawVertex(1, m.tx + a, m.ty + b, 0, u2, v1, mColor);
		Graphics.[Friend]Gfx_SetDrawVertex(2, m.tx + c, m.ty + d, 0, u1, v2, mColor);
		Graphics.[Friend]Gfx_CopyDrawVertex(3, 2);
		Graphics.[Friend]Gfx_CopyDrawVertex(4, 1);
		Graphics.[Friend]Gfx_SetDrawVertex(5, m.tx + (a + c), m.ty + (b + d), 0, u2, v2, mColor);*/

	}
}