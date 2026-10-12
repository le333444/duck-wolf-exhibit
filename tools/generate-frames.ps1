# Generates the "鸭狼" jump-and-bite animation frames from the source photo.
#   Step 1: extract the pencil drawing as a transparent cutout (local-background subtraction).
#   Step 2: composite 5 motion frames (5 frames played inside 1 second) + a neutral base pose.
param(
  [string]$Source = 'D:\dsh\duck-wolf-site\assets\duck-wolf-source.jpg',
  [string]$OutDir = 'D:\dsh\duck-wolf-site\assets\frames',
  [switch]$CutoutOnly
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$sdAsm = [System.Drawing.Bitmap].Assembly.Location

$code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

public static class WolfFrames
{
    static double Lum(byte b, byte g, byte r) { return 0.299 * r + 0.587 * g + 0.114 * b; }

    static double[] BoxBlur(double[] src, int w, int h, int r)
    {
        double[] tmp = new double[src.Length];
        double[] dst = new double[src.Length];
        int count = 2 * r + 1;
        for (int y = 0; y < h; y++)
        {
            int row = y * w;
            double sum = 0;
            for (int k = -r; k <= r; k++) { int xx = Math.Min(w - 1, Math.Max(0, k)); sum += src[row + xx]; }
            for (int x = 0; x < w; x++)
            {
                tmp[row + x] = sum / count;
                int addX = Math.Min(w - 1, x + r + 1);
                int subX = Math.Max(0, x - r);
                sum += src[row + addX] - src[row + subX];
            }
        }
        for (int x = 0; x < w; x++)
        {
            double sum = 0;
            for (int k = -r; k <= r; k++) { int yy = Math.Min(h - 1, Math.Max(0, k)); sum += tmp[yy * w + x]; }
            for (int y = 0; y < h; y++)
            {
                dst[y * w + x] = sum / count;
                int addY = Math.Min(h - 1, y + r + 1);
                int subY = Math.Max(0, y - r);
                sum += tmp[addY * w + x] - tmp[subY * w + x];
            }
        }
        return dst;
    }

    public static void Cutout(string srcPath, string outPath, int cx, int cy, int cw, int ch,
                              int outW, int outH, int radius, double offset, double span, double gamma)
    {
        using (var src = new Bitmap(srcPath))
        using (var small = new Bitmap(outW, outH, PixelFormat.Format32bppArgb))
        {
            using (var g = Graphics.FromImage(small))
            {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(src, new Rectangle(0, 0, outW, outH), new Rectangle(cx, cy, cw, ch), GraphicsUnit.Pixel);
            }
            int n = outW * outH;
            double[] lum = new double[n];
            var rect = new Rectangle(0, 0, outW, outH);
            var data = small.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            byte[] buf = new byte[data.Stride * outH];
            Marshal.Copy(data.Scan0, buf, 0, buf.Length);
            for (int y = 0; y < outH; y++)
                for (int x = 0; x < outW; x++)
                {
                    int i = y * data.Stride + x * 4;
                    lum[y * outW + x] = Lum(buf[i], buf[i + 1], buf[i + 2]);
                }
            double[] bg = BoxBlur(BoxBlur(lum, outW, outH, radius), outW, outH, radius);
            for (int y = 0; y < outH; y++)
                for (int x = 0; x < outW; x++)
                {
                    int idx = y * outW + x, i = y * data.Stride + x * 4;
                    double diff = bg[idx] - lum[idx];
                    double a = (diff - offset) / span;
                    if (a < 0) a = 0; else if (a > 1) a = 1;
                    a = Math.Pow(a, gamma);
                    buf[i] = 40; buf[i + 1] = 34; buf[i + 2] = 30;  // BGR: near-black ink
                    buf[i + 3] = (byte)Math.Round(a * 255.0);
                }
            Marshal.Copy(buf, 0, data.Scan0, buf.Length);
            small.UnlockBits(data);
            small.Save(outPath, ImageFormat.Png);
        }
    }

    // Recolors an existing cutout to a solid ink tone while keeping its alpha (used for the base pose).
    public static void Frame(string cutoutPng, string outPng, int canvasW, int canvasH,
                             int baseX, int baseY, double scale, double angleDeg, int dx, int dy,
                             bool speedLines, int lineSeed)
    {
        using (var cut = new Bitmap(cutoutPng))
        using (var canvas = new Bitmap(canvasW, canvasH, PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(canvas))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;

            float cxp = baseX + cut.Width / 2f, cyp = baseY + cut.Height / 2f;

            if (speedLines)
            {
                var rnd = new Random(lineSeed);
                var pen = new Pen(Color.FromArgb(120, 70, 62, 55), 3.2f);
                pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
                int groundY = baseY + cut.Height - 8;
                for (int k = 0; k < 9; k++)
                {
                    float lx = baseX + 40 + (float)(k * (cut.Width - 80) / 8.0) + rnd.Next(-18, 18);
                    float ly = groundY + rnd.Next(2, 46) - dy * 0.28f;
                    float len = rnd.Next(22, 52);
                    g.DrawLine(pen, lx, ly, lx - len * 0.35f, ly + len);
                }
                pen.Dispose();
            }

            var m = new Matrix();
            m.Translate(cxp + dx, cyp + dy);
            m.Rotate((float)angleDeg);
            m.Scale((float)scale, (float)scale);
            m.Translate(-cxp, -cyp);
            g.Transform = m;
            g.DrawImage(cut, new Rectangle(baseX, baseY, cut.Width, cut.Height));
            g.ResetTransform();
            canvas.Save(outPng, ImageFormat.Png);
        }
    }
}
'@

Add-Type -TypeDefinition $code -ReferencedAssemblies $sdAsm -Language CSharp

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# --- geometry ---------------------------------------------------------------
# Source is 1085x984. Crop away the dark desk strip on the left and the shadow
# below the paper; the drawing itself runs from x~40 to x~1080, y~5 to y~845.
$cropX = 30; $cropY = 0; $cropW = 1050; $cropH = 880
$cutW = 700; $cutH = [int][Math]::Round($cutW * $cropH / $cropW)
$canvasW = 900; $canvasH = 800; $baseX = 100; $baseY = 150

$cutout = Join-Path $OutDir '_cutout.png'
Write-Output "cutout ${cutW}x${cutH} -> $cutout"
[WolfFrames]::Cutout($Source, $cutout, $cropX, $cropY, $cropW, $cropH, $cutW, $cutH, 22, 6.0, 38.0, 0.85)

if ($CutoutOnly) { Write-Output 'cutout only'; exit 0 }

# --- 5 frames, played inside 1 second (180 ms each) + neutral base pose -----
$frames = @(
    @{ n = 'base';    scale = 1.00; ang =  0.0; dx =   0; dy =   0; lines = $false },
    @{ n = 'frame-1'; scale = 1.00; ang = -1.5; dx =  -6; dy =  26; lines = $false },  # crouch
    @{ n = 'frame-2'; scale = 1.05; ang = -6.0; dx =   6; dy = -42; lines = $true  },  # leap
    @{ n = 'frame-3'; scale = 1.13; ang = -13.0; dx = 26; dy = -96; lines = $true  },  # lunge, jaws wide
    @{ n = 'frame-4'; scale = 1.08; ang =  -5.0; dx = 14; dy = -52; lines = $true  },  # snap shut
    @{ n = 'frame-5'; scale = 1.01; ang =   2.0; dx =   4; dy =  30; lines = $false }   # drop back
)
$i = 0
foreach ($f in $frames) {
    $out = Join-Path $OutDir ("{0}.png" -f $f.n)
    [WolfFrames]::Frame($cutout, $out, $canvasW, $canvasH, $baseX, $baseY, $f.scale, $f.ang, $f.dx, $f.dy, $f.lines, (100 + $i * 7))
    $i++
}
Remove-Item $cutout -Force
Get-ChildItem $OutDir -Filter *.png | Sort-Object Name | Select-Object Name, Length | Format-Table -AutoSize
