# GammaLib.ps1 - nucleo compartilhado do filtro de luz azul.
# Aplica a rampa de gamma por NOME de monitor. O GetDC(NULL) generico falha
# com erro 87 em drivers Intel Xe; CreateDC("\\.\DISPLAYn") funciona.

if (-not ("GammaCtl" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class GammaCtl {
    [DllImport("gdi32.dll", SetLastError=true)]
    public static extern bool SetDeviceGammaRamp(IntPtr hDC, ref RAMP lpRamp);
    [DllImport("gdi32.dll", SetLastError=true)]
    public static extern IntPtr CreateDC(string driver, string device, string port, IntPtr pMode);
    [DllImport("gdi32.dll")]
    public static extern bool DeleteDC(IntPtr hdc);
    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);

    [StructLayout(LayoutKind.Sequential)]
    public struct RAMP {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public UInt16[] Red;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public UInt16[] Green;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public UInt16[] Blue;
    }

    // Aplica em cada monitor informado. Retorna quantos aceitaram.
    public static int ApplyAll(double rf, double gf, double bf, string[] devices) {
        RAMP ramp = new RAMP();
        ramp.Red   = new UInt16[256];
        ramp.Green = new UInt16[256];
        ramp.Blue  = new UInt16[256];

        for (int i = 0; i < 256; i++) {
            double v = i * 257.0;
            ramp.Red[i]   = (UInt16)Math.Max(0, Math.Min(65535, v * rf));
            ramp.Green[i] = (UInt16)Math.Max(0, Math.Min(65535, v * gf));
            ramp.Blue[i]  = (UInt16)Math.Max(0, Math.Min(65535, v * bf));
        }

        int applied = 0;
        foreach (string dev in devices) {
            IntPtr hdc = CreateDC(dev, null, null, IntPtr.Zero);
            if (hdc == IntPtr.Zero) continue;
            if (SetDeviceGammaRamp(hdc, ref ramp)) applied++;
            DeleteDC(hdc);
        }
        return applied;
    }
}
"@
}

function Get-DisplayDevices {
    Add-Type -AssemblyName System.Windows.Forms
    return @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object { $_.DeviceName })
}

# Aplica o filtro. $Level 0..100; $On=$false restaura as cores originais.
# Retorna a quantidade de monitores que aceitaram (0 = falhou em todos).
function Set-BlueLightFilter {
    param([bool]$On, [int]$Level)

    $factor = if ($On) { $Level / 100.0 } else { 0.0 }
    $rf = 1.0
    $gf = 1.0 - (0.32 * $factor)
    $bf = 1.0 - (0.62 * $factor)

    return [GammaCtl]::ApplyAll($rf, $gf, $bf, (Get-DisplayDevices))
}
