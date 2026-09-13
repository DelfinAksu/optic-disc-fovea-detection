function metrics = evaluateFoveaLocalization(projectRoot, setName)
%EVALUATEFOVEALOCALIZATION  Evaluate fovea detection on IDRiD C.Localization.
%
%   metrics = evaluateFoveaLocalization(projectRoot, set)
%
% Returns: struct with fields successRate, meanError, medianError, fscore, n.

if nargin < 1 || isempty(projectRoot); projectRoot = pwd; end
if nargin < 2 || isempty(setName); setName = 'test'; end
setName = lower(setName);

warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');

imgDir = fullfile(projectRoot, 'data', 'raw', 'C.Localization', 'images', setName);
fvFile = fullfile(projectRoot, 'data', 'raw', 'C.Localization', ...
                  'annotation', 'fovea', [setName '.csv']);

metricsDir = fullfile(projectRoot, 'results', 'metrics');
if ~exist(metricsDir, 'dir'); mkdir(metricsDir); end

fvGT     = readtable(fvFile);
imgFiles = dir(fullfile(imgDir, '*.jpg'));

imageNames = strings(0, 1);
predX = []; predY = [];
gtX512 = []; gtY512 = [];
errors = []; success = [];

threshold = 40;

for i = 1:numel(imgFiles)
    imgPath = fullfile(imgDir, imgFiles(i).name);
    img     = imread(imgPath);

    pre = preprocessFundusImage(img);
    [odCx, odCy]    = detectOpticDiscCenter(pre);
    [fvCx, fvCy, ~] = detectFoveaCenter(pre, odCx, odCy);

    [~, baseName, ~] = fileparts(imgFiles(i).name);
    rowIdx = find(strcmp(fvGT.ImageNo, baseName));
    if isempty(rowIdx); continue; end

    gtCx = fvGT.X_Coordinate(rowIdx); gtCy = fvGT.Y_Coordinate(rowIdx);
    sx = 512 / size(img, 2); sy = 512 / size(img, 1);
    gtCxScaled = gtCx * sx; gtCyScaled = gtCy * sy;

    err = sqrt((fvCx - gtCxScaled)^2 + (fvCy - gtCyScaled)^2);

    imageNames(end+1, 1) = string(baseName);
    predX(end+1, 1)     = fvCx;
    predY(end+1, 1)     = fvCy;
    gtX512(end+1, 1)    = gtCxScaled;
    gtY512(end+1, 1)    = gtCyScaled;
    errors(end+1, 1)    = err;
    success(end+1, 1)   = err < threshold;
end

N  = numel(errors);
nC = sum(success);
SR = 100 * nC / N;
P  = nC / N;
R  = nC / N;
F1 = (P + R > 0) * 2 * P * R / max(P + R, eps);

fprintf('\n--- Fovea Localization [%s set] ---\n', setName);
fprintf('  N: %d   Mean: %.2f px   Median: %.2f px   Std: %.2f px\n', N, mean(errors), median(errors), std(errors));
fprintf('  Success rate (< %d px): %.2f%%\n', threshold, SR);
fprintf('  F-score:                %.4f\n', F1);

T = table(imageNames, predX, predY, gtX512, gtY512, errors, success, ...
    'VariableNames', {'ImageName','PredX','PredY','GT_X_512','GT_Y_512','Error_px','Success'});
T = sortrows(T, 'Error_px', 'descend');
csvPath = fullfile(metricsDir, ['fovea_localization_image_errors_' setName '.csv']);
writetable(T, csvPath);

if nargout > 0
    metrics.successRate = SR;
    metrics.meanError   = mean(errors);
    metrics.medianError = median(errors);
    metrics.fscore      = F1;
    metrics.n           = N;
end

end
