# Diagnostico: descobre por que SetDeviceGammaRamp esta falhando.
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class GDiag {
    [DllImport("gdi32.dll", SetLastError=true)]
    public static extern bool SetDeviceGammaRamp(IntPtr hDC, ref RAMP lpRamp);
    [DllImport("gdi32.dll", SetLastError=true)]
    public static extern bool GetDeviceGammaRamp(IntPtr hDC, ref RAMP lpRamp);
    [DllImport("gdi32.dll", SetLastError=true)]
    public static extern IntPtr CreateDC(string driver, string device, string port, IntPtr pMode);
    [DllImport("gdi32.dll")]
    public static extern bool DeleteDC(IntPtr hdc);
    [DllImport("gdi32.dll")]
    public static extern int GetDeviceCaps(IntPtr hdc, int index);
    [DllImport("user32.dll")]
    public static extern IntPtr GetDC(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

    [StructLayout(LayoutKind.Sequential)]
    public struct RAMP {
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public UInt16[] Red;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public UInt16[] Green;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)] public UInt16[] Blue;
    }

    public static RAMP NewRamp() {
        RAMP r = new RAMP();
        r.Red = new UInt16[256]; r.Green = new UInt16[256]; r.Blue = new UInt16[256];
        return r;
    }

    public static string Probe(IntPtr hdc, string label) {
        if (hdc == IntPtr.Zero) return label + ": DC nulo";

        // COLORMGMTCAPS = 121; CM_GAMMA_RAMP = 2
        int caps = GetDeviceCaps(hdc, 121);

        RAMP r = NewRamp();
        bool canRead = GetDeviceGammaRamp(hdc, ref r);
        int readErr = Marshal.GetLastWin32Error();

        // Se leu, reescreve exatamente o que leu (nao deveria ser recusado por faixa).
        bool canWrite = SetDeviceGammaRamp(hdc, ref r);
        int writeErr = Marshal.GetLastWin32Error();

        return string.Format(
            "{0}: COLORMGMTCAPS={1} (bit CM_GAMMA_RAMP={2}) | leitura={3} err={4} | escrita={5} err={6} | amostra R[128]={7}",
            label, caps, (caps & 2) != 0, canRead, readErr, canWrite, writeErr,
            canRead ? r.Red[128].ToString() : "n/a");
    }
}
"@

# 1) DC da tela inteira (o que eu vinha usando)
$hdc = [GDiag]::GetDC([IntPtr]::Zero)
[GDiag]::Probe($hdc, "GetDC(NULL)")
[GDiag]::ReleaseDC([IntPtr]::Zero, $hdc) | Out-Null

# 2) DC criado explicitamente para o driver DISPLAY
$dc2 = [GDiag]::CreateDC("DISPLAY", $null, $null, [IntPtr]::Zero)
[GDiag]::Probe($dc2, "CreateDC(DISPLAY)")
[GDiag]::DeleteDC($dc2) | Out-Null

# 3) DC por nome de cada monitor ativo
Add-Type -AssemblyName System.Windows.Forms
foreach ($scr in [System.Windows.Forms.Screen]::AllScreens) {
    $dc3 = [GDiag]::CreateDC($scr.DeviceName, $null, $null, [IntPtr]::Zero)
    [GDiag]::Probe($dc3, "CreateDC($($scr.DeviceName))")
    [GDiag]::DeleteDC($dc3) | Out-Null
}
