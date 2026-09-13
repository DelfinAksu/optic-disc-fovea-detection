function metrics = evaluateODSegmentation(projectRoot, setName)
%EVALUATEODSEGMENTATION  Evaluate OD segmentation on IDRiD A.Segmentation.
%
%   metrics = evaluateODSegmentation(projectRoot, set)
%
% Returns: struct with fields meanDice, meanIoU, meanFscore, n. Note that
% F-score = Dice coefficient for binary pixel classification.

if nargin < 1 || isempty(projectRoot); projectRoot = pwd; end
if nargin < 2 || isempty(setName); setName = 'test'; end
setName = lower(setName);

warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');

imgDir = fullfile(projectRoot, 'data', 'raw', 'A.Segmentation', 'images', setName);
mskDir = fullfile(projectRoot, 'data', 'raw', 'A.Segmentation', 'masks',  setName);

metricsDir = fullfile(projectRoot, 'results', 'metrics');
if ~exist(metricsDir, 'dir'); mkdir(metricsDir); end

imgFiles = dir(fullfile(imgDir, '*.jpg'));

imageNames = strings(0,1);
diceVals  = []; iouVals  = []; precVals = []; recVals = []; fscoreVals = [];
predAreas = []; gtAreas = [];

for i = 1:numel(imgFiles)
    imgPath = fullfile(imgDir, imgFiles(i).name);
    img     = imread(imgPath);

    [~, baseName, ~] = fileparts(imgFiles(i).name);
    mskPath = fullfile(mskDir, [baseName '_OD.tif']);
    if ~exist(mskPath, 'file'); continue; end

    maskGT    = imread(mskPath) > 0;
    maskGT512 = imresize(maskGT, [512 512], 'nearest');

    pre               = preprocessFundusImage(img);
    [odCx, odCy, dbg] = detectOpticDiscCenter(pre);
    predMask          = segmentOpticDisc(pre, odCx, odCy, dbg);

    TP = nnz(predMask & maskGT512);
    FP = nnz(predMask & ~maskGT512);
    FN = nnz(~predMask & maskGT512);
    sumP = TP + FP; sumG = TP + FN; uni = TP + FP + FN;

    diceI = (sumP + sumG > 0) * 2 * TP / max(sumP + sumG, eps);
    iouI  = (uni > 0) * TP / max(uni, eps);
    prec  = (sumP > 0) * TP / max(sumP, eps);
    rec   = (sumG > 0) * TP / max(sumG, eps);
    F1    = (prec + rec > 0) * 2 * prec * rec / max(prec + rec, eps);

    imageNames(end+1, 1) = string(baseName);
    diceVals(end+1, 1)   = diceI;
    iouVals(end+1, 1)    = iouI;
    precVals(end+1, 1)   = prec;
    recVals(end+1, 1)    = rec;
    fscoreVals(end+1, 1) = F1;
    predAreas(end+1, 1)  = sumP;
    gtAreas(end+1, 1)    = sumG;
end

fprintf('\n--- OD Segmentation [%s set] ---\n', setName);
fprintf('  N: %d   Mean Dice: %.4f   Median Dice: %.4f   Std: %.4f\n', ...
    numel(diceVals), mean(diceVals), median(diceVals), std(diceVals));
fprintf('  Mean IoU: %.4f   Mean Precision: %.4f   Mean Recall: %.4f\n', ...
    mean(iouVals), mean(precVals), mean(recVals));
fprintf('  Mean F-score: %.4f  (= mean Dice)\n', mean(fscoreVals));
fprintf('  Dice > 0.7: %.1f%%   > 0.8: %.1f%%   > 0.9: %.1f%%\n', ...
    100 * mean(diceVals > 0.7), 100 * mean(diceVals > 0.8), 100 * mean(diceVals > 0.9));

T = table(imageNames, diceVals, iouVals, precVals, recVals, fscoreVals, predAreas, gtAreas, ...
    'VariableNames', {'ImageName','Dice','IoU','Precision','Recall','Fscore','PredArea','GTArea'});
T = sortrows(T, 'Dice', 'ascend');
csvPath = fullfile(metricsDir, ['od_segmentation_image_scores_' setName '.csv']);
writetable(T, csvPath);

if nargout > 0
    metrics.meanDice    = mean(diceVals);
    metrics.medianDice  = median(diceVals);
    metrics.meanIoU     = mean(iouVals);
    metrics.meanFscore  = mean(fscoreVals);
    metrics.n           = numel(diceVals);
end

end
