clc; clear;

projectRoot = fileparts(mfilename('fullpath'));
if isempty(projectRoot); projectRoot = pwd; end
addpath(genpath(fullfile(projectRoot, 'src')));

testImgDir = fullfile(projectRoot, 'data', 'raw', 'C.Localization', 'images', 'test');
odGTFile   = fullfile(projectRoot, 'data', 'raw', 'C.Localization', ...
                      'annotation', 'optic-disc', 'test.csv');
figDir     = fullfile(projectRoot, 'results', 'figures', 'localization_new');

if exist(figDir, 'dir')
    rmdir(figDir, 's');
end
mkdir(figDir);

odGT     = readtable(odGTFile);
imgFiles = dir(fullfile(testImgDir, '*.jpg'));

threshold = 40;
errors    = nan(numel(imgFiles), 1);

for i = 1:numel(imgFiles)

    imgPath = fullfile(testImgDir, imgFiles(i).name);
    img     = imread(imgPath);

    pre = preprocessFundusImage(img);
    [odCx, odCy, debugInfo] = detectOpticDiscCenter(pre);

    [~, baseName, ~] = fileparts(imgFiles(i).name);
    rowIdx = find(strcmp(odGT.ImageNo, baseName));

    gtCx = []; gtCy = []; err = NaN; success = NaN;
    if ~isempty(rowIdx)
        gtCxOrig = odGT.X_Coordinate(rowIdx);
        gtCyOrig = odGT.Y_Coordinate(rowIdx);
        scaleX   = 512 / size(img, 2);
        scaleY   = 512 / size(img, 1);
        gtCx     = gtCxOrig * scaleX;
        gtCy     = gtCyOrig * scaleY;
        err      = sqrt((odCx - gtCx)^2 + (odCy - gtCy)^2);
        success  = err < threshold;
        errors(i) = err;
    end

    if isnan(err)
        statusStr = 'GT yok';
    else
        statusStr = sprintf('Err = %.1f px  |  %s', err, ...
                            ternary(success, 'BASARILI', 'BASARISIZ'));
    end

    titleStr = sprintf('%s  —  %s', baseName, statusStr);

    fig = visualizeODDetection(img, pre, debugInfo, odCx, odCy, gtCx, gtCy, titleStr);

    outPng = fullfile(figDir, [baseName '_debug.png']);
    exportgraphics(fig, outPng, 'Resolution', 130);
    close(fig);

    if mod(i, 10) == 0
        fprintf('Processed %d / %d\n', i, numel(imgFiles));
    end
end

fprintf('\nVisualization figures saved to:\n  %s\n', figDir);

if any(~isnan(errors))
    fprintf('Mean error: %.2f px  |  Success rate (<%dpx): %.2f%%\n', ...
            mean(errors,'omitnan'), threshold, ...
            100 * sum(errors < threshold) / sum(~isnan(errors)));
end

% --- helper ---
function out = ternary(cond, a, b)
    if cond; out = a; else; out = b; end
end
