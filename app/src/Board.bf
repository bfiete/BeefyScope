using System;
using Beefy.widgets;
using Beefy.gfx;
using Beefy.theme.dark;
using System.Collections;

namespace BeefyScope;

class Board : Widget
{
	List<ViewWidget> mViews = new .() ~ delete _;

	public this()
	{
		WaveformView view = new WaveformView();
		AddWidget(view);
		mViews.Add(view);
		ResizeComponents();

		/*var button = new DarkButton();
		button.Label = "OK";
		button.Resize(80, 80, 200, 40);
		AddWidget(button);*/
	}

	public override void Draw(Graphics g)
	{
		
		using (g.PushColor(0xFF282830))
			g.FillRect(0, 0, mWidth, mHeight);

		/*using (g.PushColor(0xFF6060A0))
			g.FillRect(mUpdateCnt % 100, 20, 3, 20);*/

		g.SetFont(gApp.mSmFont);
		g.DrawString(scope $"FPS:{(int)gApp.mLastFPS} SAMPLES:{BSApp.GetSamplerDistance(gApp.mWaveform.mStartPt, gApp.mWaveform.mEndPt)/1000}k", 8, 0);
	}

	public void ResizeComponents()
	{
		var view = mViews.Back;
		view.Resize(0, 0, mWidth, mHeight);
	}

	public override void Resize(float x, float y, float width, float height)
	{
		base.Resize(x, y, width, height);
		ResizeComponents();
	}

	public override void KeyDown(KeyCode keyCode, bool isRepeat)
	{
		base.KeyDown(keyCode, isRepeat);

		/*if (keyCode == (.)'1')
		{
			for (int i < 1000000)
			{
				gApp.mSamplerMemory[i] = (uint8)(Math.Sin(i * 0.1f) * 127.0f + 128);
			}
		}*/

		if (keyCode == (.)'S')
		{
			gApp.StartSampling(.OneShot);
		}
	}

	public override void KeyChar(char32 c)
	{
		base.KeyChar(c);

		for (var view in mViews)
		{
			if (var waveformView = view as WaveformView)
			{
				switch (c)
				{
				case 't':
					waveformView.IncTimeScale();
				case 'T':
					waveformView.DecTimeScale();
				}
			}
		}
	}
}