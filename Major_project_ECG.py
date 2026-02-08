"""
ECG Filtering and Q31 Fixed-Point Conversion Script
---------------------------------------------------
Source: ECGData.mat (PhysioNet-based ECG dataset)
Author: T G BALASUBRAMANIAM
Date: 07-01-26

Description:
    (i)     Loads ECG recordings from a MATLAB (.mat) dataset sampled at 360 Hz.
    (ii)    Extracts a single ECG channel for analysis.
    (iii)   Applies a 6th-order Butterworth high-pass filter (1 Hz cutoff) to remove
            baseline wander from the ECG signal.
    (iv)    Applies a notch filter (40 Hz) to suppress powerline and high-frequency
            interference components.
    (v)     Computes and visualizes the frequency spectrum (FFT) of the raw and
            filtered ECG signals.
    (vi)    Selects a 0-2 second ECG segment suitable for FIFO / hardware input.
    (vii)   Converts the filtered ECG segment to Q31 fixed-point format.
    (viii)  Saves the filtered ECG segment in floating-point, Q31 fixed-point, and
            reconstructed floating-point formats as CSV files.
    (ix)    Performs a sanity check by comparing the original floating-point ECG
            segment with the Q31 reconstructed ECG signal.
    (x)     Plots the raw ECG, filtered ECG, and their corresponding FFTs for
            time- and frequency-domain analysis.

Purpose:
    This script prepares an ECG signal for fixed-point digital signal processing
    and hardware implementation by validating Q31 quantization accuracy against
    floating-point reference data.

Notes:
    - Sampling frequency: 360 Hz.
    - Q31 scaling factor used: 2^31.
    - CSV files contain signal amplitude only (no headers or time column).
    - Intended for DSP, FPGA, and SoC-based ECG processing workflows.
"""

import scipy.io as sio
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import butter, filtfilt, iirnotch
import pandas as pd

# --------------------------------------------------
# LOAD ECG DATASET
# --------------------------------------------------
file_path = r"C:\Users\aravi\Downloads\ECGData\ECGData.mat"
data = sio.loadmat(file_path)

ECGData = data['ECGData']
ecg_signals = ECGData['Data'][0, 0]          # (162, 65536)
labels = ECGData['Labels'][0, 0].squeeze()

# --------------------------------------------------
# PARAMETERS
# --------------------------------------------------
Fs = 360
example_index = 0

# --------------------------------------------------
# TIME AXIS
# --------------------------------------------------
num_samples = ecg_signals.shape[1]
t = np.arange(num_samples) / Fs

# --------------------------------------------------
# RAW ECG
# --------------------------------------------------
raw_ecg = ecg_signals[example_index, :]

# --------------------------------------------------
# HIGH-PASS FILTER
# --------------------------------------------------
cutoff = 1
order = 6
wn = cutoff / (Fs / 2)

b_hpf, a_hpf = butter(order, wn, btype='highpass')
hpf_ecg = filtfilt(b_hpf, a_hpf, raw_ecg)

# --------------------------------------------------
# NOTCH FILTER
# --------------------------------------------------
notch_freq = 40
Q = 30

w0 = notch_freq / (Fs / 2)
b_notch, a_notch = iirnotch(w0, Q)

final_ecg = filtfilt(b_notch, a_notch, hpf_ecg)

# --------------------------------------------------
# FFT
# --------------------------------------------------
N = len(raw_ecg)
freqs = np.fft.rfftfreq(N, 1 / Fs)

fft_raw = np.abs(np.fft.rfft(raw_ecg))
fft_final = np.abs(np.fft.rfft(final_ecg))

# --------------------------------------------------
# SELECT TIME WINDOW (FIFO INPUT)
# --------------------------------------------------
start_time = 0
end_time   = 2

start_idx = int(start_time * Fs)
end_idx   = int(end_time * Fs)

t_segment   = t[start_idx:end_idx]
ecg_segment = final_ecg[start_idx:end_idx]

# --------------------------------------------------
# Q31 FIXED-POINT CONVERSION
# --------------------------------------------------
Q31_SCALE = 2**31

ecg_q31 = np.int32(
    np.clip(ecg_segment * Q31_SCALE, -2**31, 2**31 - 1)
)

# --------------------------------------------------
# SAVE FLOATING-POINT ECG TO CSV
# --------------------------------------------------
float_csv_path = (
    r"C:\Users\aravi\Downloads\study materials download\S8\PROJECT"
    r"\report diagrams\filtered_ecg_float_0_to_2s.csv"
)

pd.DataFrame(ecg_segment).to_csv(
    float_csv_path,
    index=False,
    header=False
)

print(f"Floating-point ECG saved to: {float_csv_path}")

# --------------------------------------------------
# SAVE Q31 ECG TO CSV
# --------------------------------------------------
q31_csv_path = (
    r"C:\Users\aravi\Downloads\study materials download\S8\PROJECT"
    r"\report diagrams\filtered_ecg_q31_0_to_2s.csv"
)

pd.DataFrame(ecg_q31).to_csv(
    q31_csv_path,
    index=False,
    header=False
)

print(f"Q31 ECG segment saved to: {q31_csv_path}")


# --------------------------------------------------
# CONVERT Q31 BACK TO FLOAT
# --------------------------------------------------
ecg_float_from_q31 = ecg_q31.astype(np.float64) / Q31_SCALE

# --------------------------------------------------
# SAVE RECONSTRUCTED FLOAT ECG TO CSV
# --------------------------------------------------
float_recon_csv_path = (
    r"C:\Users\aravi\Downloads\study materials download\S8\PROJECT"
    r"\report diagrams\filtered_ecg_float_from_q31_0_to_2s.csv"
)

pd.DataFrame(ecg_float_from_q31).to_csv(
    float_recon_csv_path,
    index=False,
    header=False
)

print(f"Reconstructed float ECG saved to: {float_recon_csv_path}")

# --------------------------------------------------
# FLOAT vs Q31 SANITY CHECK
# --------------------------------------------------
plt.figure(figsize=(8, 3))
plt.plot(ecg_segment[:300], label="Float ECG", linewidth=1)
plt.plot(ecg_q31[:300] / Q31_SCALE, '--', label="Q31 Reconstructed", linewidth=1)
plt.title("Float vs Q31 Quantized ECG")
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.show()

# --------------------------------------------------
# PLOTTING
# --------------------------------------------------
plt.figure(figsize=(12, 10))

plt.subplot(3, 2, 1)
plt.plot(t, raw_ecg, color="red", linewidth=0.7)
plt.title("Raw ECG Signal")
plt.grid(True)

plt.subplot(3, 2, 2)
plt.plot(t, final_ecg, color="green", linewidth=0.7)
plt.title("Filtered ECG (HPF + Notch)")
plt.grid(True)

plt.subplot(3, 2, 3)
plt.plot(freqs, fft_raw, color="red")
plt.xlim(0, 5)
plt.ylim(0, 1000)
plt.title("FFT of Raw ECG")
plt.grid(True)

plt.subplot(3, 2, 4)
plt.plot(freqs, fft_final, color="green")
plt.xlim(0, 5)
plt.ylim(0, 1000)
plt.title("FFT of Filtered ECG")
plt.grid(True)

plt.subplot(3, 2, 5)
plt.plot(t, raw_ecg, color="red", linewidth=0.7)
plt.xlim(0, 5)
plt.title("Raw ECG (0-5 s)")
plt.grid(True)

plt.subplot(3, 2, 6)
plt.plot(t, final_ecg, color="green", linewidth=0.7)
plt.xlim(0, 5)
plt.title("Filtered ECG (0-5 s)")
plt.grid(True)

plt.tight_layout()
plt.show()

