using Beefy;
using Beefy.widgets;
using System;
using Beefy.theme;
using Beefy.theme.dark;
using Beefy.gfx;
using System.Collections;

namespace BeefyScope;

struct Waveform
{
	public enum Flags
	{
		Ch1 = 1,
		Ch2 = 2,
		Ch3 = 4,
		Ch4 = 8,
	}

	public bool HasData => mFlags != 0;

	public Flags mFlags;
	public int64 mStartPt;
	public int64 mTriggerPt;
	public int64 mEndPt;
	public int32 mSamplerRateDivisor;
}

struct ChannelConfig
{
	public bool mEnabled;
	public String mLabel = new String();
	public int32 mRateDivisor = 100;

	public void Dispose()
	{
		delete mLabel;
	}
}

class BSApp : BFApp
{
	public enum SampleKind
	{
		None,
		Auto,
		Normal,
		OneShot,
	}

	public enum SamplerMode
	{
		Empty,
		OneShot_Running,
		OneShot_Captured,
	}

	public const int32 cLODCount = 5;
	public const int32[5] cLODScale = .(16, 256, 4*1024, 64*1024, 1024*1024);
	public const int64 cSamplerRate = 5'000'000'000;
	public const int64 cSamplerMemSize = 128*1024*1024;

	public WidgetWindow mWidgetWindow;
	public Font mSmFont ~ delete _;

	public SamplerMode mSamplerMode;

	public List<uint8> mSamplerMemory = new .() ~ delete _;
	public List<uint8>[5] mLODMemory = .(new .(), new .(), new .(), new .(), new .());
	public Waveform mWaveform;
	public Board mBoard;

	public int32 mWaveformTailBlock;
	public int32 mWaveformHeadBlock;

	public int64 mSamplerTail;
	public int64 mSamplerHead;
	public double mSamplerUpdatePct;
	public uint8 mSamplerLastSample;
	public int64 mSamplerGenIdx;
	public int32 mSamplerRateDivisor = 5000; // 1 Mhz
	public int32 mLODSectionIdx;

	public ChannelConfig[4] mChannelConfig;

	public this()
	{
		gApp = this;

		mSamplerMemory.Resize(cSamplerMemSize);
		for (int lod < cLODCount)
			mLODMemory[lod].Resize(cSamplerMemSize/cLODScale[lod] * 2);
		for (var channelConfig in ref mChannelConfig)
			channelConfig = .();
	}

	public ~this()
	{
		DeleteAndNullify!(DarkTheme.sDarkTheme);

		for (var channelConfig in ref mChannelConfig)
			channelConfig.Dispose();
	}

	public override void Init()
	{
		base.Init();

		DarkTheme.SetScale(2);
		DarkTheme theme = new DarkTheme();
		theme.Init();
		ThemeFactory.mDefault = theme;

		BFWindow.Flags flags = .Border | .Caption | .SysMenu | .QuitOnClose | .ClientSized;
#if !BF_PLATFORM_WINDOWS && !BF_DEBUG
		flags |= .Fullscreen;
#endif
		mBoard = new .();
		mWidgetWindow = new WidgetWindow(null, "BeefTest2D", 64, 64, 1920, 1080,  flags, mBoard);
		mBoard.SetFocus();

		DarkTheme.sDarkTheme.mSmallFont.Dispose();
		DarkTheme.sDarkTheme.mSmallFont.Load(scope $"{mInstallDir}/fonts/segoeui.ttf", 26);

		mSmFont = new Font();
		mSmFont.Load(scope $"{mInstallDir}/fonts/segoeui.ttf", 22);
	}

	public static int64 GetSamplerDistance(int64 startIdx, int64 endIdx)
	{
		return (endIdx + cSamplerMemSize - startIdx) % cSamplerMemSize;
	}

	public void StartSampling(SampleKind kind)
	{
		ClearWaveform();

		if (kind == .None)
		{
			return;
		}

		mSamplerTail = 0;
		mSamplerHead = 0;
		mSamplerUpdatePct = 0;
		mLODSectionIdx = 0;

		switch (kind)
		{
		case .OneShot:
			mSamplerMode = .OneShot_Running;
		default:
		}
	}

	void UpdateSamples()
	{
		if (mSamplerMode != .OneShot_Running)
			return;

		mSamplerUpdatePct += 8192;

		int32 chunkSize = 4096;
		while (mSamplerUpdatePct > chunkSize)
		{
			mSamplerUpdatePct -= chunkSize;

			uint8* samplePtr = mSamplerMemory.Ptr + mSamplerHead;
			for (int32 blockOfs < chunkSize)
			{
				uint8 newSample = (uint8)(Math.Cos(mSamplerGenIdx * 0.000003) * Math.Sin(mSamplerGenIdx * 0.0003) * Math.Sin(mSamplerGenIdx++ * 0.004 /*0.1*/) * 127.0f + 128);

				*(samplePtr++) = newSample;

				if ((!mWaveform.HasData) && (mSamplerLastSample < 180) && (newSample >= 180))
				{
					mWaveform.mFlags = .Ch1;
					mWaveform.mSamplerRateDivisor = mSamplerRateDivisor;
					mWaveform.mTriggerPt = mSamplerHead + blockOfs;
					mWaveform.mStartPt = mSamplerTail;

					//mSamplerTriggerBlock = mSamplerHeadBlock;
					//mSamplerTriggerBlockOfs = 0;
				}

				mSamplerLastSample = newSample;

				/*for (int lod = 1; lod <= 3; lod++)
				{

				}*/
			}

			if (mWaveform.HasData)
				mWaveform.mEndPt = (mSamplerHead + chunkSize) % cSamplerMemSize;

			// LOD0
			{
				uint8* lodSrcPtr = mSamplerMemory.Ptr + mSamplerHead;
				uint8* lodDestPtr = mLODMemory[0].Ptr + mSamplerHead / (16/2);
				int destLen = chunkSize / 16;

				for (int destIdx < destLen)
				{
					uint8 minVal = 255;
					uint8 maxVal = 0;
					for (int i < 16)
					{
						uint8 sample = *(lodSrcPtr++);
						minVal = Math.Min(sample, minVal);
						maxVal = Math.Max(sample, maxVal);
					}
					*(lodDestPtr++) = minVal;
					*(lodDestPtr++) = maxVal;
				}
			}

			uint8 totalMinVal = 255;
			uint8 totalMaxVal = 0;

			// LOD1, LOD2
			for (int lod in 1...2)
			{
				uint8* lodSrcPtr = mLODMemory[lod-1].Ptr + mSamplerHead / (BSApp.cLODScale[lod-1] / 2);
				uint8* lodDestPtr = mLODMemory[lod].Ptr + mSamplerHead / (BSApp.cLODScale[lod] / 2);
				int destLen = chunkSize / BSApp.cLODScale[lod];

				for (int destIdx < destLen)
				{
					uint8 minVal = 255;
					uint8 maxVal = 0;
					for (int i < 16)
					{
						minVal = Math.Min(*(lodSrcPtr++), minVal);
						maxVal = Math.Max(*(lodSrcPtr++), maxVal);
					}
					*(lodDestPtr++) = minVal;
					*(lodDestPtr++) = maxVal;

					if (lod == 1)
					{
						totalMinVal = Math.Min(minVal, totalMinVal);
						totalMaxVal = Math.Max(maxVal, totalMaxVal);
					}
				}
			}

			for (int lod in 3...4)
			{
				uint8* lodDestPtr = mLODMemory[lod].Ptr + mSamplerHead / (BSApp.cLODScale[lod] / 2);

				//int dest

				if (mSamplerHead % BSApp.cLODScale[lod] == 0)
				{
					*(lodDestPtr++) = totalMinVal;
					*(lodDestPtr++) = totalMaxVal;
				}
				else
				{
					*(lodDestPtr++) = Math.Min(*lodDestPtr, totalMinVal);
					*(lodDestPtr++) = Math.Max(*lodDestPtr, totalMaxVal);
				}
			}

			mSamplerHead = (mSamplerHead + chunkSize) % cSamplerMemSize;
			/*if (mSamplerHead == mSamplerTail)
				mSamplerHead = (mSamplerTail + 1) % cSamplerBlockCount;*/

			if (mWaveform.HasData)
			{
				int64 captureLength = GetSamplerDistance(mWaveform.mStartPt, mWaveform.mEndPt);

				//if (postTriggerBlocks >= cSamplerBlockCount/2)
				if (captureLength >= 10'000'000)
				{
					switch (mSamplerMode)
					{
					case .OneShot_Running:
						mSamplerMode = .OneShot_Captured;
					default:
					}
				}
			}
		}
	}

	public override void Update(bool batchStart)
	{
		base.Update(batchStart);

		UpdateSamples();
	}

	public void ClearWaveform()
	{
		mWaveform = default;
	}
}

static
{
	public static BSApp gApp;
}