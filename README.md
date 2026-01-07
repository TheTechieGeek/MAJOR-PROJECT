# MAJOR-PROJECT
**ECG Baseline Wander Removal – Python**

This repository contains a Python script for preprocessing electrocardiogram (ECG) signals using digital filtering techniques to remove low‑frequency baseline wander and visualize the effect in both time and frequency domains.[1][2]

## Overview

- Loads ECG recordings from a MATLAB file (`ECGData.mat`) derived from a PhysioNet‑style dataset structure.[3]
- Uses a standardized sampling frequency of **360 Hz** for ECG analysis.  
- Focuses on removing baseline wander using a high‑pass Butterworth filter and comparing raw vs filtered signals via FFT plots.[2][1]

## Processing Pipeline

- Extracts ECG traces and labels from the `ECGData` structure in the `.mat` file.  
- Selects one ECG example and builds a time axis for visualization.  
- Designs a **6th‑order Butterworth high‑pass filter** with a **1 Hz cutoff** and applies zero‑phase filtering (`filtfilt`) to suppress baseline drift without phase distortion.[4][5]

## Frequency Analysis

- Computes the single‑sided FFT of both raw and filtered ECG signals.  
- Plots the magnitude spectra, zoomed in on the low‑frequency band (0–3 Hz), to highlight attenuation of baseline wander components while preserving the main ECG morphology.[1][2]

## Visualization

- Generates side‑by‑side time‑domain plots for the raw and filtered ECG signals over an initial 5‑second window.  
- Produces frequency‑domain plots for direct comparison of spectral content before and after filtering, useful for teaching and evaluation of ECG preprocessing methods.[6][1]

## Dependencies

- Python 3.x  
- `numpy`, `scipy`, `matplotlib`  
- MATLAB‑formatted ECG dataset file (`ECGData.mat`) compatible with `scipy.io.loadmat`.[7]

[1](https://pmc.ncbi.nlm.nih.gov/articles/PMC5361052/)
[2](https://pmc.ncbi.nlm.nih.gov/articles/PMC3673325/)
[3](https://github.com/mathworks/physionet_ECG_data)
[4](https://pmc.ncbi.nlm.nih.gov/articles/PMC12656279/)
[5](https://www.sciencedirect.com/topics/computer-science/butterworth-filter)
[6](https://www.gehealthcare.com/insights/article/a-guide-to-ecg-signal-filtering)
[7](https://physionet.org/content/ecgkit/1.0/common/read_ECG.m)
[8](https://www.sciencedirect.com/topics/computer-science/baseline-wander)
[9](https://cinc.org/archives/2013/pdf/1171.pdf)
[10](https://ieeexplore.ieee.org/document/8683084/)
[11](https://www.mathworks.com/help/signal/ug/classify-ecg-signals-using-long-short-term-memory-networks.html)
[12](https://www.physionet.org/content/ephnogram/1.0.0/MAT/)
[13](https://onlinelibrary.wiley.com/doi/10.1155/2013/896056)
[14](https://www.reddit.com/r/matlab/comments/nni3p3/ecg_file_loading/)
[15](https://idc-online.com/technical_references/pdfs/electrical_engineering/FILTERING%20OF%20ECG%20SIGNAL%20USING.pdf)
[16](https://www.warse.org/IJATCSE/static/pdf/file/ijatcse41952020.pdf)
[17](https://www.iosrjournals.org/iosr-jece/papers/Vol6-Issue6/G0663744.pdf)
[18](https://ris.utwente.nl/ws/files/6562487/Alste86ecg.pdf)
[19](https://jics.org.br/ojs/index.php/JICS/article/download/698/454)
[20](https://physionet.org/content/ecg-arrhythmia/1.0.0/)
