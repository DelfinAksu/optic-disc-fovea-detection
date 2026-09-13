function main()

clc; close all;

projectRoot = fileparts(mfilename('fullpath'));
if isempty(projectRoot); projectRoot = pwd; end

addpath(genpath(fullfile(projectRoot, 'src')));
addpath(fullfile(projectRoot, 'scripts'));

% Suppress unimportant MATLAB warnings for a clean console
warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');
warning('off', 'MATLAB:legend:IgnoringExtraEntries');

fprintf('\n');
fprintf('================================================================\n');
fprintf('  BIM472 Project - Optic Disc / Fovea Pipeline\n');
fprintf('  Reproducibility Run\n');
fprintf('  Project root: %s\n', projectRoot);
fprintf('================================================================\n');

%% =========================================================
%  TEST set evaluations
%  =========================================================
fprintf('\n>>> TEST set evaluation\n');

m_od_test    = evaluateODLocalization(projectRoot,    'test');
m_fov_test   = evaluateFoveaLocalization(projectRoot, 'test');
m_seg_test   = evaluateODSegmentation(projectRoot,    'test');

%% =========================================================
%  TRAIN set evaluations (independent validation)
%  =========================================================
fprintf('\n>>> TRAIN set evaluation\n');

m_od_train   = evaluateODLocalization(projectRoot,    'train');
m_fov_train  = evaluateFoveaLocalization(projectRoot, 'train');
m_seg_train  = evaluateODSegmentation(projectRoot,    'train');

%% =========================================================
%  Final summary table
%  =========================================================
fprintf('\n');
fprintf('================================================================\n');
fprintf('                    FINAL SUMMARY  (F-score)\n');
fprintf('================================================================\n');
fprintf('  Module                     | TEST set        | TRAIN set\n');
fprintf('  ---------------------------|-----------------|-----------------\n');
fprintf('  OD Localization   F-score  | %.4f          | %.4f\n', m_od_test.fscore,   m_od_train.fscore);
fprintf('  Fovea Localization F-score | %.4f          | %.4f\n', m_fov_test.fscore,  m_fov_train.fscore);
fprintf('  OD Segmentation    F-score | %.4f          | %.4f   (= mean Dice)\n', m_seg_test.meanFscore, m_seg_train.meanFscore);
fprintf('================================================================\n');
fprintf('  Module                     | Test (errors)   | Train (errors)\n');
fprintf('  ---------------------------|-----------------|-----------------\n');
fprintf('  OD Localization (px)       | mean %.2f      | mean %.2f\n',  m_od_test.meanError,  m_od_train.meanError);
fprintf('                             | median %.2f    | median %.2f\n',  m_od_test.medianError, m_od_train.medianError);
fprintf('  Fovea Localization (px)    | mean %.2f     | mean %.2f\n',   m_fov_test.meanError, m_fov_train.meanError);
fprintf('                             | median %.2f   | median %.2f\n',   m_fov_test.medianError, m_fov_train.medianError);
fprintf('  OD Segmentation IoU        | %.4f          | %.4f\n', m_seg_test.meanIoU, m_seg_train.meanIoU);
fprintf('================================================================\n');

%% =========================================================
%  Single-image demo (matches the example in the assignment PDF)
%  =========================================================
fprintf('\n>>> Single-image demo\n');

samplePath = fullfile(projectRoot, 'data', 'raw', 'C.Localization', ...
                     'images', 'test', 'IDRiD_001.jpg');
if exist(samplePath, 'file')
    demoSingleImage(samplePath);
else
    fprintf('  Sample image not found at: %s\n', samplePath);
end

fprintf('\n  Done.\n');
fprintf('  - CSVs:         results/metrics/*.csv\n');
fprintf('  - Demo figure:  results/figures/demo/IDRiD_001_demo.png\n\n');

end
