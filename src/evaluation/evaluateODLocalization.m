function metrics = evaluateODLocalization(projectRoot, setName)
%EVALUATEODLOCALIZATION  Evaluate OD localization on IDRiD C.Localization.
%
%   evaluateODLocalization()                          % defaults to 'test'
%   metrics = evaluateODLocalization(projectRoot, set) % returns struct of key metrics
%
% Returns: struct with fields successRate, meanError, medianError, fscore, n.
% Reports both Success Rate and F-score in the console.

if nargin < 1 || isempty(projectRoot); projectRoot = pwd; end
if nargin < 2 || isempty(setName); setName = 'test'; end
setName = lower(setName);

warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');

imgDir = fullfile(projectRoot, 'data', 'raw', 'C.Localization', 'images', setName);
gtFile = fullfile(projectRoot, 'data', 'raw', 'C.Localization', ...
                  'annotation', 'optic-disc', [setName '.csv']);

metricsDir = fullfile(projectRoot, 'results', 'metrics');
if ~exist(metricsDir, 'dir'); mkdir(metricsDir); end

odGT = readtable(gtFile);
imgFiles = dir(fullfile(imgDir, '*.jpg'));

imageNames = strings(0,1);
predX = []; predY = [];
gtX512 = []; gtY512 = [];
errors = []; success = [];

threshold = 40;

for i = 1:numel(imgFiles)
    imgPath = fullfile(imgDir, imgFiles(i).name);
    img = imread(imgPath);
    pre = preprocessFundusImage(img);
    [odCx, odCy] = detectOpticDiscCenter(pre);

    [~, baseName, ~] = fileparts(imgFiles(i).name);
    rowIdx = find(strcmp(odGT.ImageNo, baseName));
    if isempty(rowIdx); continue; end

    gtCx = odGT.X_Coordinate(rowIdx); gtCy = odGT.Y_Coordinate(rowIdx);
    sx = 512 / size(img, 2); sy = 512 / size(img, 1);
    gtCxScaled = gtCx * sx; gtCyScaled = gtCy * sy;

    err = sqrt((odCx - gtCxScaled)^2 + (odCy - gtCyScaled)^2);

    imageNames(end+1, 1) = string(baseName);
    predX(end+1, 1)     = odCx;
    predY(end+1, 1)     = odCy;
    gtX512(end+1, 1)    = gtCxScaled;
    gtY512(end+1, 1)    = gtCyScaled;
    errors(end+1, 1)    = err;
    success(end+1, 1)   = err < threshold;
end

N = numel(errors);
nC = sum(success);
SR = 100 * nC / N;
P  = nC / N;
R  = nC / N;
F1 = (P + R > 0) * 2 * P * R / max(P + R, eps);

fprintf('\n--- OD Localization [%s set] ---\n', setName);
fprintf('  N: %d   Mean: %.2f px   Median: %.2f px   Std: %.2f px\n', N, mean(errors), median(errors), std(errors));
fprintf('  Success rate (< %d px): %.2f%%\n', threshold, SR);
fprintf('  F-score:                %.4f\n', F1);

T = table(imageNames, predX, predY, gtX512, gtY512, errors, success, ...
    'VariableNames', {'ImageName','PredX','PredY','GT_X_512','GT_Y_512','Error_px','Success'});
T = sortrows(T, 'Error_px', 'descend');
csvPath = fullfile(metricsDir, ['od_localization_image_errors_' setName '.csv']);
writetable(T, csvPath);

if nargout > 0
    metrics.successRate = SR;
    metrics.meanError   = mean(errors);
    metrics.medianError = median(errors);
    metrics.fscore      = F1;
    metrics.n           = N;
end

end
