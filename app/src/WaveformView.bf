using System;
using Beefy.gfx;
using Beefy.geom;
using System.Diagnostics;

namespace BeefyScope;

class WaveformView : ViewWidget
{
	public double mTimeOfs;
	public double mVoltOfs;

	public double mVoltsPerDivision = 2.0;
	public double mTimePerDivision = 0.0001;

	public Vector2? mMouseDownPos;
	public double mMouseDownTimeOfs;
	public double mMouseDownVoltOfs;

	public float mLastPixelsPerSample;
	public int64 mLastVisiblePtCount;

	public override void Update()
	{
		base.Update();

		if (mUpdateCnt % 200 == 0)
		{
			Debug.WriteLine($"MaxSamplesVisible:{(int)(mWidth/mLastPixelsPerSample)} LastVisiblePtCount:{mLastVisiblePtCount}");
		}
	}

	public override void Draw(Graphics g)
	{
		using (g.PushColor(0xFF6060A0))
			g.FillRect(mUpdateCnt % 100, 0, 3, 20);

		g.SetFont(gApp.mSmFont);

		/*for (int col < 10)
		{
			float lineX = (col + 1) * 1920 / 10;
			using (g.PushColor(0x80606060))
			{
				g.FillRect(lineX, 0, 1, 1080);
			}

			String label = scope $"{col * 10} ns";

			using (g.PushColor(0xFFFFFF00))
			{
				if (col < 10-1)
					g.DrawString(label, lineX, 1080 - 80, .Centered);
				else
					g.DrawString(label, lineX - 6, 1080 - 80, .Right);
			}
		}*/

		double timeXScale = mWidth / (mTimePerDivision * 10);

		int centerColIdx = (.)(-mTimeOfs / mTimePerDivision);

		for (int colOfs = -6; colOfs <= 6; colOfs++)
		{
			double time = (centerColIdx + colOfs) * mTimePerDivision;
			double x = (time + mTimeOfs) * timeXScale + mWidth / 2;

			using (g.PushColor(0x80606060))
				g.FillRect((int)x, 0, 1, mHeight);

			String label = scope .(16);
			Utils.TimeToStr(time, label);

			using (g.PushColor(0xFFFFFF00))
			{
				float drawX = (int32)x;
				float labelWidth = g.mFont.GetWidth(label);
				drawX -= labelWidth / 2;

				if (drawX < 100)
				{
					float adjust = 100 - drawX;
					if (adjust >= mWidth * 0.02f)
						continue;
					drawX += adjust;
				}

				float maxX = mWidth - labelWidth - 6;
				if (drawX > maxX)
				{
					float adjust = drawX - maxX;
					if (adjust >= mWidth * 0.02f)
						continue;
					drawX -= adjust;
				}

				g.DrawString(label, drawX, 1080 - 80, .Left);
			}
		}

		double voltYScale = mHeight / (mVoltsPerDivision * 10);

		/*for (int i < (int)mWidth)
		{
			uint8 sample = gApp.mSamplerMemory[i];
			double volts = ((sample - 128) / 127.0f) * 5.0;

			double y = -(volts + mVoltOfs) * voltYScale + mHeight / 2;

			//double div = volts / mVoltsPerDivision

			g.FillRect(i, (.)y, 1, 1);
		}*/

		//float x = 0;

		if (gApp.mWaveform.HasData)
		{
			double timePerSample = 1.0 / (BSApp.cSamplerRate / gApp.mWaveform.mSamplerRateDivisor);

			int64 curPt = gApp.mWaveform.mStartPt;
			int64 ptsLeft = BSApp.GetSamplerDistance(gApp.mWaveform.mStartPt, gApp.mWaveform.mEndPt);
			int64 triggerPtOfs = -BSApp.GetSamplerDistance(gApp.mWaveform.mStartPt, gApp.mWaveform.mTriggerPt);

			//double wantOfs = (.)(timePerSample / mTimeOfs) * timeXScale;

			double pixelsPerSample = timePerSample * timeXScale;
			int64 skipSamples = (int64)(-(mTimeOfs / timePerSample) - triggerPtOfs - (mWidth * 0.49f)/pixelsPerSample) - 1;

			mLastPixelsPerSample = (.)pixelsPerSample;

			/*if (mUpdateCnt % 60 == 0)
				Debug.WriteLine($"{(mTimeOfs / timePerSample):0.00000} {skipSamples} {pixelsPerSample}");*/

			if (skipSamples > 0)
			{
				curPt = (curPt + BSApp.cSamplerMemSize + skipSamples) % BSApp.cSamplerMemSize;
				ptsLeft -= skipSamples;
				triggerPtOfs += skipSamples;
			}

			//int64 wantOfs = (.)((mTimeOfs) / timePerSample);

			int32 visiblePtCount = 0;
			int32 lastX = -10000;
			int32 lastMinY = 0;
			int32 lastMaxY = 0;

			int32 prevDrawMinY = Int32.MinValue;
			int32 prevDrawMaxY = -Int32.MaxValue;

			int lodIdx = -1;

			if (mWidgetWindow.IsKeyDown((.)'1'))
				lodIdx = 0;
			else if (mWidgetWindow.IsKeyDown((.)'2'))
				lodIdx = 1;
			else if (mWidgetWindow.IsKeyDown((.)'3'))
				lodIdx = 2;
			else if (mWidgetWindow.IsKeyDown((.)'4'))
				lodIdx = 3;

			if (lodIdx >= 0)
			{
				WaveLoop: while (ptsLeft > BSApp.cLODScale[lodIdx])
				{
					var ptr = gApp.mLODMemory[lodIdx].Ptr + (curPt / BSApp.cLODScale[lodIdx]) * 2;
					//var endPtr = gApp.mSamplerMemory.Ptr + Math.Min(curPt + ptsLeft, curPt + 4096);

					var endPtr = ptr + Math.Min(ptsLeft / (BSApp.cLODScale[lodIdx] / 2), 128);

					int32 chunkSize = (.)(endPtr - ptr);

					while (ptr < endPtr)
					{
						uint8 sampleLo = *(ptr++);
						uint8 sampleHi = *(ptr++);
						double voltsLo = ((sampleLo - 128) / 127.0f) * 5.0;
						double voltsHi = ((sampleHi - 128) / 127.0f) * 5.0;
						int32 yLo = (.)(-(voltsLo + mVoltOfs) * voltYScale + mHeight / 2);
						int32 yHi = (.)(-(voltsHi + mVoltOfs) * voltYScale + mHeight / 2);
	
						double time = triggerPtOfs * timePerSample;
						int32 x = (.)((time + mTimeOfs) * timeXScale + mWidth / 2);

						/*using (g.PushColor(0xFFFF0000))
							g.FillRect(x, yLo, 2, 2);
						using (g.PushColor(0xFF00FF00))
							g.FillRect(x, yHi, 2, 2);*/

						if (x > 0)
						{
							if (x != lastX)
							{
								if (lastX > 0)
								{
									lastMinY = Math.Min(lastMinY, prevDrawMaxY);
									lastMaxY = Math.Max(lastMaxY, prevDrawMinY);

									g.FillRect(lastX, lastMinY, 1, lastMaxY - lastMinY + 1);
									prevDrawMinY = lastMinY;
									prevDrawMaxY = lastMaxY;
								}
	
								lastX = x;
								lastMinY = yHi;
								lastMaxY = yLo;
							}
							else
							{
								lastMinY = Math.Min(lastMinY, (int32)yHi);
								lastMaxY = Math.Max(lastMaxY, (int32)yLo);
							}
						}
	
						if (x > mWidth)
							break WaveLoop;
	
						triggerPtOfs += BSApp.cLODScale[lodIdx];
						visiblePtCount++;
					}

					curPt += chunkSize * (BSApp.cLODScale[lodIdx] / 2);
					ptsLeft -= chunkSize * (BSApp.cLODScale[lodIdx] / 2);

					//break WaveLoop;
				}
			}
			else
			{
				WaveLoop: while (ptsLeft > 0)
				{
					var ptr = gApp.mSamplerMemory.Ptr + curPt;
					var endPtr = gApp.mSamplerMemory.Ptr + Math.Min(curPt + ptsLeft, curPt + 4096);
					int32 chunkSize = (.)(endPtr - ptr);

					//double time = triggerPtOfs;

					if (pixelsPerSample > 1)
					{
						// Maxify
						while (ptr < endPtr)
						{
							uint8 sample = *(ptr++);
							double volts = ((sample - 128) / 127.0f) * 5.0;

							float y = (.)(-(volts + mVoltOfs) * voltYScale + mHeight / 2);

							//double div = volts / mVoltsPerDivision

							double time = triggerPtOfs * timePerSample;
							float x = (.)((time + mTimeOfs) * timeXScale + mWidth / 2);

							if (x >= 0)
							{
								if (visiblePtCount > 0)
								{
									int32 len = (int32)x - (int32)lastX;
									if (len > 0)
									{
										g.FillRect((int32)lastX, (int32)lastMinY, len, 1);
									}

									int32 minY = Math.Min(lastMinY, (int32)y);
									int32 maxY = Math.Max(lastMinY, (int32)y);
									if (maxY - minY > 1)
										g.FillRect((int32)x, minY, 1, maxY - minY);
								}

								g.FillRect((int32)x, (int32)y, 1, 1);
							}
							if (x > mWidth)
								break WaveLoop;

							lastX = (.)x;
							lastMinY = (.)y;
							triggerPtOfs++;
							visiblePtCount++;
						}
					}
					else
					{
						// Minify
						while (ptr < endPtr)
						{
							uint8 sample = *(ptr++);
							double volts = ((sample - 128) / 127.0f) * 5.0;

							int32 y = (.)(-(volts + mVoltOfs) * voltYScale + mHeight / 2);

							//double div = volts / mVoltsPerDivision

							double time = triggerPtOfs * timePerSample;
							int32 x = (.)((time + mTimeOfs) * timeXScale + mWidth / 2);

							if (x > 0)
							{
								lastMinY = Math.Min(lastMinY, (int32)y);
								lastMaxY = Math.Max(lastMaxY, (int32)y);

								if (x != lastX)
								{
									if (lastX > 0)
										g.FillRect(lastX, lastMinY, 1, lastMaxY - lastMinY + 1);

									lastX = x;
									lastMinY = y;
									lastMaxY = y;
								}
							}

							if (x > mWidth)
								break WaveLoop;

							triggerPtOfs++;
							visiblePtCount++;
						}
					}

					curPt += chunkSize;
					ptsLeft -= chunkSize;
					//triggerPtOfs += chunkSize;
				}
			}

			mLastVisiblePtCount = visiblePtCount;
		}

		int centerRowIdx = 0;
		for (int rowOfs = -10; rowOfs <= 10; rowOfs++)
		{
			double volts = (centerRowIdx + rowOfs) * mVoltsPerDivision;
			double y = -(volts + mVoltOfs) * voltYScale + mHeight / 2;
			using (g.PushColor(0x80606060))
				g.FillRect(0, (int)y, mWidth, 1);

			String label = scope $"{volts:0.00} V";
			using (g.PushColor(0xFFFFFF00))
			{
				g.DrawString(label, 4, (int)y - 16);
			}
		}
	}

	public override void MouseDown(float x, float y, int32 btn, int32 btnCount)
	{
		base.MouseDown(x, y, btn, btnCount);

		mMouseDownPos = .(x, y);
		mMouseDownTimeOfs = mTimeOfs;
		mMouseDownVoltOfs = mVoltOfs;

		Debug.WriteLine($"Time: {GetTimeAtX(x)} SampleIdx: {GetStartRelSampleAtX(x)}");
	}

	public override void MouseUp(float x, float y, int32 btn)
	{
		base.MouseUp(x, y, btn);

		if (mMouseFlags == 0)
			mMouseDownPos = null;
	}

	public override void MouseMove(float x, float y)
	{
		base.MouseMove(x, y);

		if (mMouseDownPos != null)
		{
			double timeYScale = mWidth / (mTimePerDivision * 10);
			mTimeOfs = mMouseDownTimeOfs + (x - mMouseDownPos.Value.mX) / timeYScale;

			double voltYScale = mHeight / (mVoltsPerDivision * 10);
			mVoltOfs = mMouseDownVoltOfs - (y - mMouseDownPos.Value.mY) / voltYScale;
		}
	}

	public void IncTimeScale()
	{
		double logBaseVal = Math.Floor(Math.Log10(mTimePerDivision));
		double baseVal = Math.Pow(10.0, (int)logBaseVal);
		int curScalar = (int)Math.Round(mTimePerDivision / baseVal);
		curScalar *= 2;

		if (curScalar > 4)
			curScalar = 10;

		mTimePerDivision = Math.Min(baseVal * curScalar, 10000);
	}

	public double GetTimeAtX(float x)
	{
		//double timePerSample = 1.0 / (BSApp.cSamplerRate / gApp.mWaveform.mSamplerRateDivisor);
		double timeXScale = mWidth / (mTimePerDivision * 10);
		//double pixelsPerSample = timePerSample * timeXScale;
		double time = (x - (mWidth / 2)) / timeXScale - mTimeOfs;

		Debug.WriteLine($"Time: {time}");
		return time;
	}

	public double GetTriggerRelSampleAtX(float x) 
	{
		double timePerSample = 1.0 / (BSApp.cSamplerRate / gApp.mWaveform.mSamplerRateDivisor);
		double timeXScale = mWidth / (mTimePerDivision * 10);
		return ((x - (mWidth / 2)) / timeXScale - mTimeOfs) / timePerSample;
	}

	public double GetStartRelSampleAtX(float x) 
	{
		return GetTriggerRelSampleAtX(x) + BSApp.GetSamplerDistance(gApp.mWaveform.mStartPt, gApp.mWaveform.mTriggerPt);
	}

	public void DecTimeScale()
	{
		double logBaseVal = Math.Floor(Math.Log10(mTimePerDivision));
		double baseVal = Math.Pow(10.0, (int)logBaseVal);
		int curScalar = (int)Math.Round(mTimePerDivision / baseVal);
		curScalar /= 2;

		if (curScalar == 0)
		{
			curScalar = 4;
			baseVal /= 10;
		}	

		mTimePerDivision = Math.Max(baseVal * curScalar, 0.000000001);
	}
}