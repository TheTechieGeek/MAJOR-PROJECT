"""
ECG Baseline Wander Removal Script
----------------------------------
Source: ECGData.mat (PhysioNet-based dataset)
Author: T G BALASUBRAMANIAM
Date: 07-01-26

Description:
    (i)     Loads ECG recordings from MATLAB file. 
    (ii)    Sampling at 360 Hz (medical standard sampling frequency).
    (iii)   Applies a 6th-order Butterworth high-pass filter (1 Hz cutoff) to remove baseline wander.
    (iv)    Applies a notch filter (40 Hz cutoff) to remove powerline interference from ECG signal.
    (v)     Plots the filtered and unfiltered ECG alongside their fft graph.
"""

import scipy.io as sio
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import butter, filtfilt

# Load the ECG dataset
file_path = r"C:\Users\aravi\Downloads\ECGData\ECGData.mat"
data = sio.loadmat(file_path)

# Extract ECG signals and labels
ECGData = data['ECGData']
ecg_signals = ECGData['Data'][0, 0]          # (162, 65536)
labels = ECGData['Labels'][0, 0].squeeze()

# Parameters
Fs = 360 # Standardised sampling frequency of 360 Hz is taken
example_index = 0

# Time axis
num_samples = ecg_signals.shape[1]
t = np.arange(num_samples) / Fs

# Raw ECG
raw_ecg = ecg_signals[example_index, :]

# --------------------------------
# HIGH-PASS FILTER (Baseline Wander Removal)
# --------------------------------
cutoff = 1  # Hz
order = 6

# Normalized cutoff frequency
wn = cutoff / (Fs / 2)

# Design Butterworth HPF
b, a = butter(order, wn, btype='highpass')

# Zero-phase filtering
filtered_ecg = filtfilt(b, a, raw_ecg)

# --------------------------------
# FFT COMPUTATION
# --------------------------------
N = len(raw_ecg)
freqs = np.fft.rfftfreq(N, 1/Fs)

fft_raw = np.abs(np.fft.rfft(raw_ecg)) # frequency response of raw ECG signal
fft_filtered = np.abs(np.fft.rfft(filtered_ecg)) # frequency response of filtered ECG signal.

# --------------------------------
# PLOTTING
# --------------------------------
plt.figure(figsize=(12, 10))

# --- Time Domain of raw ECG signal ---
plt.subplot(2, 2, 1)
plt.plot(t, raw_ecg, linewidth=0.7)
plt.title("Raw ECG Signal")
plt.xlabel("Time")
plt.xlim(0, 5)
plt.ylabel("Amplitude")
#plt.ylim(0, 2)
plt.grid(True)

# --- Time Domain of Filtered ECG signal ---
plt.subplot(2, 2, 2)
plt.plot(t, filtered_ecg, color='green', linewidth=0.7)
plt.title("Filtered ECG (Baseline Wander Removed – HPF @ 0.5 Hz)")
plt.xlim(0, 5)
plt.ylabel("Amplitude")
plt.grid(True)
# --- Frequency Domain of raw ECG signal ---
plt.subplot(2, 1, 1)
plt.plot(freqs, fft_raw, label="Raw ECG", color = "blue")
plt.title("FFT Comparison (Baseline Wander Removal)")
plt.xlabel("Frequency (Hz)")
plt.xlim(0, 3)   # Baseline wander region
plt.ylabel("Magnitude")
plt.ylim(0, 1000)
plt.legend()
plt.grid(True)

# --- Frequency Domain of filtered ECG signal ---
plt.subplot(2, 1, 2)
plt.plot(freqs, fft_filtered, label="Filtered ECG", color = "green")
plt.title("FFT Comparison (Baseline Wander Removed)")
plt.xlim(0, 3)   # Baseline wander region
plt.xlabel("Frequency (Hz)")
plt.ylabel("Magnitude")
plt.ylim(0, 1000)
plt.legend()
plt.grid(True)

# tight_layout to prevent overlapping of plots
plt.tight_layout()
plt.show()
