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
from scipy.signal import butter, filtfilt, iirnotch
import pandas as pd

# Load the ECG dataset
file_path = r"C:\Users\aravi\Downloads\ECGData\ECGData.mat"
data = sio.loadmat(file_path)

# Extract ECG signals and labels
ECGData = data['ECGData']
ecg_signals = ECGData['Data'][0, 0]          # (162, 65536)
labels = ECGData['Labels'][0, 0].squeeze()

# Parameters
Fs = 360  # Sampling frequency
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
wn = cutoff / (Fs / 2)

b_hpf, a_hpf = butter(order, wn, btype='highpass')
final_ecg = filtfilt(b_hpf, a_hpf, raw_ecg)
'''
# --------------------------------
# NOTCH FILTER (Powerline / EMG Removal)
# --------------------------------
notch_freq = 40  # Hz
Q = 30           # Quality factor (controls notch width)

w0 = notch_freq / (Fs / 2)
b_notch, a_notch = iirnotch(w0, Q)

final_ecg = filtfilt(b_notch, a_notch, hpf_ecg)
'''

# --------------------------------
# FFT COMPUTATION
# --------------------------------
N = len(raw_ecg)
freqs = np.fft.rfftfreq(N, 1/Fs)

fft_raw = np.abs(np.fft.rfft(raw_ecg))
fft_final = np.abs(np.fft.rfft(final_ecg))

# --------------------------------
# SELECT TIME WINDOW
# --------------------------------
start_time = 0    # seconds
end_time   = 2    # seconds

start_idx = int(start_time * Fs)
end_idx   = int(end_time * Fs)

t_segment = t[start_idx:end_idx]
ecg_segment = final_ecg[start_idx:end_idx]

# --------------------------------
# SAVE SEGMENT TO CSV
# --------------------------------
output_csv_path = r"C:\Users\aravi\Downloads\study materials download\S8\PROJECT\report diagrams\filtered_ecg_0_to_5s.csv"

df_segment = pd.DataFrame({
    "Time (s)": t_segment,
    "Filtered ECG (HPF + Notch)": ecg_segment
})

df_segment.to_csv(output_csv_path, index=False)

print(f"ECG segment saved: {output_csv_path}")

# --------------------------------
# PLOTTING
# --------------------------------
plt.figure(figsize=(12, 10))

# Raw ECG
plt.subplot(3, 2, 1)
plt.plot(t, raw_ecg, color="red", linewidth=0.7)
plt.title("Raw ECG Signal")
plt.ylabel("Amplitude")
plt.grid(True)

# HPF + Notch ECG
plt.subplot(3, 2, 2)
plt.plot(t, final_ecg, color="green", linewidth=0.7)
plt.title("Filtered ECG (HPF @ 1 Hz + Notch @ 40 Hz)")
plt.ylabel("Amplitude")
plt.grid(True)

# FFT Raw
plt.subplot(3, 2, 3)
plt.plot(freqs, fft_raw, color="red")
plt.title("FFT of Raw ECG")
plt.xlim(0, 5)
plt.ylim(0, 1000)
plt.ylabel("Magnitude")
plt.grid(True)

# FFT Final
plt.subplot(3, 2, 4)
plt.plot(freqs, fft_final, color="green")
plt.title("FFT of Filtered ECG")
plt.xlim(0, 5)
plt.ylim(0, 1000)
plt.ylabel("Magnitude")
plt.grid(True)

# Zoomed Raw
plt.subplot(3, 2, 5)
plt.plot(t, raw_ecg, color="red", linewidth=0.7)
plt.xlim(0, 5)
plt.title("Raw ECG (0–5 s)")
plt.grid(True)

# Zoomed Filtered
plt.subplot(3, 2, 6)
plt.plot(t, final_ecg, color="green", linewidth=0.7)
plt.xlim(0, 5)
plt.title("Filtered ECG (0–5 s)")
plt.grid(True)

plt.tight_layout()
plt.show()
