# Optic Disc and Fovea Detection

Automatic localization of the optic disc (OD) and fovea center coordinates, and segmentation of the optic disc boundary, on retinal fundus images — implemented as a classical (non machine-learning) image processing pipeline in MATLAB.

Developed as part of the Image Processing course at Eskişehir Technical University.

## Overview

Given a retinal fundus image, the pipeline:

- **Locates the optic disc center** `[ODx, ODy]` by fusing multi-scale brightness maps, multi-orientation vessel density, a lesion penalty, and an anatomical horizontal-band prior into a single score map.
- **Locates the fovea center** `[Fx, Fy]` using anatomical priors (distance and direction relative to the predicted OD center) combined with a local darkness map.
- **Segments the optic disc** as a binary mask via ROI extraction, vessel inpainting, adaptive (Otsu + percentile) thresholding, and morphological cleanup.

Every step is a textbook image processing technique — CLAHE, Gaussian smoothing, unsharp masking, multi-orientation morphological (bottom-hat/top-hat) filtering, Otsu and percentile-adaptive thresholding, morphological reconstruction, connected-component analysis, and inpainting — so every intermediate result is interpretable, with no deep learning involved.

The pipeline is evaluated on the **IDRiD (Indian Diabetic Retinopathy Image Dataset)**, using the F-score (precision/recall based on the 40 px success threshold) for localization and the Dice coefficient / IoU for segmentation, as required by the project spec.

## Results

Final results after tuning:

| Module | Test set | Train set (independent validation) |
|---|---|---|
| OD Localization — success rate (< 40 px) | **97.09%** (9.95 px mean error) | 96.13% (13.29 px mean error) |
| Fovea Localization — success rate (< 40 px) | **97.09%** (16.30 px mean error) | 94.92% (18.41 px mean error) |
| OD Segmentation — mean Dice / IoU | **0.859 / 0.763** | 0.840 / 0.743 |

An ablation study and a parameter-sensitivity sweep (see `results/experiments/` and `results/report_figures/pipeline_steps/05_experiments/`) identified the adaptive percentile threshold used to build the bright-candidate mask as the dominant factor: raising it from 0.95 to 0.99 alone lifted OD localization success from 80.58% to 97.09%.

## Repository structure

```
├── main.m                     # Entry point: runs full evaluation (test + train) and a single-image demo
├── src/
│   ├── preprocessing/         # Shared preprocessing (channel separation, CLAHE, smoothing)
│   ├── localization/          # OD and fovea center detection
│   ├── segmentation/          # OD boundary segmentation
│   ├── evaluation/            # F-score / Dice / IoU evaluation over the IDRiD sets
│   ├── experiments/           # Ablation study, parameter sensitivity, failure analysis
│   └── visualization/         # Overlay and result visualization helpers
├── scripts/
│   ├── demoSingleImage.m      # Runs the full pipeline on one image and saves a demo figure
│   └── generateIPFigures.m    # Generates the step-by-step pipeline figures used in the report
├── results/
│   ├── metrics/                 # Per-image error/score CSVs (test and train)
│   ├── experiments/             # Ablation and parameter-sensitivity CSVs
│   └── report_figures/          # Pipeline-step and experiment figures
└── data/                      # IDRiD dataset (not included — see Dataset setup below)
```

## Dataset setup

The [IDRiD dataset](https://idrid.grand-challenge.org/Home/) is not included in this repository (it's excluded via `.gitignore`). To reproduce the results:

1. Download the **A. Segmentation** and **C. Localization** subsets of IDRiD.
2. Place them under `data/raw/` so that the structure looks like:
   ```
   data/raw/A.Segmentation/...
   data/raw/C.Localization/...
   ```

## Running the pipeline

Requires MATLAB (no additional toolboxes beyond Image Processing Toolbox).

```matlab
main
```

This runs the full OD localization, fovea localization, and OD segmentation evaluation on both the IDRiD test and train sets, prints a summary table (F-score, mean/median error, IoU), and produces a single-image demo figure. Outputs are written to:

- `results/metrics/*.csv` — per-image metrics
- `results/figures/demo/` — single-image demo visualization

To reproduce the ablation study, parameter-sensitivity sweep, or failure analysis individually, run the corresponding scripts in `src/experiments/` (e.g. `runAblationStudy`, `runParameterSensitivity`, `runFailureAnalysis`).

## References

1. P. Porwal et al., "Indian Diabetic Retinopathy Image Dataset (IDRiD): A Database for Diabetic Retinopathy Screening Research," *Data*, vol. 3, no. 3, p. 25, Jul. 2018.
2. N. Otsu, "A Threshold Selection Method from Gray-Level Histograms," *IEEE Trans. Syst. Man Cybern.*, vol. 9, no. 1, pp. 62–66, Jan. 1979.
3. Shijian Lu, "Accurate and Efficient Optic Disc Detection and Segmentation by a Circular Transformation," *IEEE Trans. Med. Imaging*, vol. 30, no. 12, pp. 2126–2133, Dec. 2011.
4. R. Romero-Oraá, M. García, J. Oraá-Pérez, M. I. López, R. Hornero, "A robust method for the automatic location of the optic disc and the fovea in fundus images," *Comput. Methods Programs Biomed.*, vol. 196, p. 105599, Nov. 2020.
5. B. Dinç, Y. Kaya, "A Novel Hybrid Optic Disc Detection and Fovea Localization Method Integrating Region-Based Convnet and Mathematical Approach," *Wirel. Pers. Commun.*, vol. 129, no. 4, pp. 2727–2748, Apr. 2023.
