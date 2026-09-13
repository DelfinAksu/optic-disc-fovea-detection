function runAblationStudy(projectRoot)
%RUNABLATIONSTUDY  Run OD localization with each pipeline component disabled
%and measure the resulting success rate. Saves a comparison CSV.

if nargin < 1
    projectRoot = pwd;
end
addpath(genpath(fullfile(projectRoot, 'src')));

testImgDir = fullfile(projectRoot, 'data', 'raw', 'C.Localization', 'images', 'test');
odGTFile   = fullfile(projectRoot, 'data', 'raw', 'C.Localization', ...
                      'annotation', 'optic-disc', 'test.csv');
outDir     = fullfile(projectRoot, 'results', 'experiments');
if ~exist(outDir, 'dir'); mkdir(outDir); end

odGT     = readtable(odGTFile);
imgFiles = dir(fullfile(testImgDir, '*.jpg'));
N        = numel(imgFiles);

threshold = 40;

% --- Define ablation variants ---
variants = {
    %  name                                  config
    'A1_full_pipeline',                      struct();
    'A2_no_cc_argmax',                       struct('ccMode','argmax');
    'A3_old_sum_side_decision',              struct('ccMode','sumSide');
    'A4_no_lesion_penalty',                  struct('useLesionPenalty',     false);
    'A5_no_vessel_features',                 struct('useVesselFeatures',    false);
    'A6_no_anatomical_prior',                struct('useAnatomicalPrior',   false);
    'A7_fixed_threshold_065',                struct('useAdaptiveThreshold', false);
    'A8_no_unsharp_mask',                    struct('useUnsharpMask',       false);
};
nVariants = size(variants, 1);

% Pre-load all images and GT into memory
fprintf('Pre-loading %d images...\n', N);
imgs   = cell(N, 1);
gtX    = nan(N, 1);
gtY    = nan(N, 1);
names  = strings(N, 1);

for i = 1:N
    imgs{i} = imread(fullfile(testImgDir, imgFiles(i).name));
    [~, baseName, ~] = fileparts(imgFiles(i).name);
    names(i) = string(baseName);
    rowIdx = find(strcmp(odGT.ImageNo, baseName));
    if ~isempty(rowIdx)
        scaleX  = 512 / size(imgs{i}, 2);
        scaleY  = 512 / size(imgs{i}, 1);
        gtX(i)  = odGT.X_Coordinate(rowIdx) * scaleX;
        gtY(i)  = odGT.Y_Coordinate(rowIdx) * scaleY;
    end
end

% --- Run each variant ---
results = cell(nVariants, 6);  % name, success%, meanErr, medianErr, #success, time

for v = 1:nVariants
    vName   = variants{v, 1};
    vConfig = variants{v, 2};

    fprintf('\n[%d/%d] Running variant: %s\n', v, nVariants, vName);

    errs = nan(N, 1);
    succ = false(N, 1);

    tStart = tic;
    for i = 1:N
        if isnan(gtX(i)); continue; end
        pre = preprocessFundusImage(imgs{i});
        [odCx, odCy] = detectOpticDiscCenterAblation(pre, vConfig);
        e = sqrt((odCx - gtX(i))^2 + (odCy - gtY(i))^2);
        errs(i) = e;
        succ(i) = e < threshold;
    end
    elapsed = toc(tStart);

    valid = ~isnan(errs);
    nValid = sum(valid);
    nSucc  = sum(succ);
    sr     = 100 * nSucc / nValid;
    mErr   = mean(errs(valid));
    medErr = median(errs(valid));

    fprintf('  Success rate: %.2f%%  Mean err: %.2f  Median err: %.2f  (%.1f s)\n', ...
        sr, mErr, medErr, elapsed);

    results{v, 1} = vName;
    results{v, 2} = sr;
    results{v, 3} = mErr;
    results{v, 4} = medErr;
    results{v, 5} = nSucc;
    results{v, 6} = elapsed;
end

% --- Print final table ---
fprintf('\n\n===== ABLATION STUDY SUMMARY =====\n');
fprintf('%-30s %12s %12s %12s %10s %8s\n', ...
        'Variant', 'Success%', 'Mean(px)', 'Median(px)', 'NumSucc', 'Time(s)');
fprintf('%s\n', repmat('-', 1, 90));
for v = 1:nVariants
    fprintf('%-30s %12.2f %12.2f %12.2f %10d %8.1f\n', ...
        results{v,1}, results{v,2}, results{v,3}, results{v,4}, results{v,5}, results{v,6});
end

% --- Save CSV ---
T = table( ...
    string({results{:,1}})', ...
    cell2mat(results(:,2)), ...
    cell2mat(results(:,3)), ...
    cell2mat(results(:,4)), ...
    cell2mat(results(:,5)), ...
    cell2mat(results(:,6)), ...
    'VariableNames', {'Variant','SuccessRate','MeanError','MedianError','NumSuccess','TimeSec'});

csvPath = fullfile(outDir, 'ablation_study.csv');
writetable(T, csvPath);
fprintf('\nSaved CSV to: %s\n', csvPath);

end
