function runParameterSensitivity(projectRoot)
%RUNPARAMETERSENSITIVITY  Sweep three priority parameters and measure success
%rate / mean error on the IDRiD test set. Saves CSV + per-parameter PNG plots.
%
% Parameters tested (5 values each, 15 runs total):
%   1. thresholdPercentile  : [0.85 0.90 0.95 0.97 0.99]
%   2. weightVesselDensity  : [0.00 0.15 0.30 0.45 0.60]
%   3. weightLesionPenalty  : [0.10 0.30 0.60 1.00 1.50]

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

% Pre-load all images and GT
fprintf('Pre-loading %d images...\n', N);
imgs = cell(N,1); gtX = nan(N,1); gtY = nan(N,1);
for i = 1:N
    imgs{i} = imread(fullfile(testImgDir, imgFiles(i).name));
    [~, baseName, ~] = fileparts(imgFiles(i).name);
    rowIdx = find(strcmp(odGT.ImageNo, baseName));
    if ~isempty(rowIdx)
        sx = 512 / size(imgs{i}, 2);
        sy = 512 / size(imgs{i}, 1);
        gtX(i) = odGT.X_Coordinate(rowIdx) * sx;
        gtY(i) = odGT.Y_Coordinate(rowIdx) * sy;
    end
end

% Pre-compute pre.red / pre.green only once for each image
fprintf('Preprocessing all images once...\n');
pres = cell(N,1);
for i = 1:N
    pres{i} = preprocessFundusImage(imgs{i});
end

% Sweep definitions
sweeps = {
    'thresholdPercentile',  [0.85 0.90 0.95 0.97 0.99];
    'weightVesselDensity',  [0.00 0.15 0.30 0.45 0.60];
    'weightLesionPenalty',  [0.10 0.30 0.60 1.00 1.50];
};

allResults = {};   % rows: paramName, value, success%, meanErr, medianErr

for s = 1:size(sweeps, 1)
    pName  = sweeps{s, 1};
    pVals  = sweeps{s, 2};

    fprintf('\n=== Sweep %d/%d : %s ===\n', s, size(sweeps,1), pName);

    for v = 1:numel(pVals)
        pVal = pVals(v);
        cfg  = struct();
        cfg.(pName) = pVal;

        errs = nan(N, 1);
        succ = false(N, 1);

        tStart = tic;
        for i = 1:N
            if isnan(gtX(i)); continue; end
            [odCx, odCy] = detectOpticDiscCenterAblation(pres{i}, cfg);
            e = sqrt((odCx - gtX(i))^2 + (odCy - gtY(i))^2);
            errs(i) = e;
            succ(i) = e < threshold;
        end
        elapsed = toc(tStart);

        valid = ~isnan(errs);
        sr     = 100 * sum(succ) / sum(valid);
        mErr   = mean(errs(valid));
        medErr = median(errs(valid));

        fprintf('  %s = %5.3f  ->  Success: %.2f%%  Mean: %.2f  Median: %.2f  (%.1f s)\n', ...
            pName, pVal, sr, mErr, medErr, elapsed);

        allResults(end+1, :) = {pName, pVal, sr, mErr, medErr};
    end
end

% --- Save CSV ---
T = table( ...
    string({allResults{:,1}})', ...
    cell2mat(allResults(:,2)), ...
    cell2mat(allResults(:,3)), ...
    cell2mat(allResults(:,4)), ...
    cell2mat(allResults(:,5)), ...
    'VariableNames', {'Parameter','Value','SuccessRate','MeanError','MedianError'});

csvPath = fullfile(outDir, 'parameter_sensitivity.csv');
writetable(T, csvPath);
fprintf('\nSaved CSV to: %s\n', csvPath);

% --- Generate plots ---
figDir = fullfile(projectRoot, 'results', 'report_figures', ...
                  'pipeline_steps', '05_experiments');
if ~exist(figDir, 'dir'); mkdir(figDir); end

for s = 1:size(sweeps, 1)
    pName = sweeps{s, 1};
    pVals = sweeps{s, 2};

    rows = strcmp(allResults(:, 1), pName);
    sr   = cell2mat(allResults(rows, 3));
    me   = cell2mat(allResults(rows, 4));
    medE = cell2mat(allResults(rows, 5));

    fig = figure('Visible','off','Position',[50 50 1100 400],'Color','w');

    subplot(1,2,1);
    plot(pVals, sr, 'o-b', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
    xlabel(pName, 'Interpreter','none','FontSize',11);
    ylabel('Success Rate (%)','FontSize',11);
    title({sprintf('Success rate vs %s', pName)},'FontSize',11,'Interpreter','none');
    grid on;
    for j = 1:numel(pVals)
        text(pVals(j), sr(j) + 1, sprintf('%.1f%%',sr(j)), 'FontSize', 9);
    end

    subplot(1,2,2);
    yyaxis left
    plot(pVals, me, 's-', 'LineWidth', 2, 'MarkerSize', 8); ylabel('Mean Error (px)');
    yyaxis right
    plot(pVals, medE, 'd-', 'LineWidth', 2, 'MarkerSize', 8); ylabel('Median Error (px)');
    xlabel(pName, 'Interpreter','none','FontSize',11);
    title({sprintf('Errors vs %s', pName)},'FontSize',11,'Interpreter','none');
    grid on;

    sgtitle(sprintf('Parameter Sensitivity: %s', pName), ...
            'FontSize',13,'FontWeight','bold','Interpreter','none');

    outPng = fullfile(figDir, sprintf('B_sensitivity_%s.png', pName));
    try
        exportgraphics(fig, outPng, 'Resolution', 130, 'BackgroundColor','white');
    catch
        saveas(fig, outPng);
    end
    close(fig);
    fprintf('Plot saved: %s\n', outPng);
end

% --- Print final summary ---
fprintf('\n===== PARAMETER SENSITIVITY SUMMARY =====\n');
fprintf('%-25s %8s %12s %12s %12s\n', ...
        'Parameter','Value','Success%','Mean(px)','Median(px)');
fprintf('%s\n', repmat('-', 1, 75));
for r = 1:size(allResults,1)
    fprintf('%-25s %8.3f %12.2f %12.2f %12.2f\n', ...
        allResults{r,1}, allResults{r,2}, allResults{r,3}, allResults{r,4}, allResults{r,5});
end

end
