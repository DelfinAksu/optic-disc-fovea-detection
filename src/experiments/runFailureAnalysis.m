function runFailureAnalysis(projectRoot)


if nargin < 1
    projectRoot = pwd;
end
addpath(genpath(fullfile(projectRoot, 'src')));

testImgDir = fullfile(projectRoot, 'data', 'raw', 'C.Localization', 'images', 'test');
odGTFile   = fullfile(projectRoot, 'data', 'raw', 'C.Localization', ...
                      'annotation', 'optic-disc', 'test.csv');
outDir     = fullfile(projectRoot, 'results', 'experiments');
figDir     = fullfile(projectRoot, 'results', 'report_figures', ...
                      'pipeline_steps', '05_experiments');
if ~exist(outDir, 'dir'); mkdir(outDir); end
if ~exist(figDir, 'dir'); mkdir(figDir); end

odGT     = readtable(odGTFile);
imgFiles = dir(fullfile(testImgDir, '*.jpg'));
N        = numel(imgFiles);
threshold = 40;

failures = {};   % rows: name, err, predX, predY, gtX, gtY, category

for i = 1:N
    imgPath = fullfile(testImgDir, imgFiles(i).name);
    img     = imread(imgPath);
    [~, baseName, ~] = fileparts(imgFiles(i).name);
    rowIdx = find(strcmp(odGT.ImageNo, baseName));
    if isempty(rowIdx); continue; end

    sx = 512 / size(img, 2); sy = 512 / size(img, 1);
    gtX = odGT.X_Coordinate(rowIdx) * sx;
    gtY = odGT.Y_Coordinate(rowIdx) * sy;

    pre = preprocessFundusImage(img);
    [odCx, odCy, dbg] = detectOpticDiscCenter(pre);

    err = sqrt((odCx - gtX)^2 + (odCy - gtY)^2);
    if err < threshold; continue; end   % success - skip

    % Classify the failure
    [H, W] = size(pre.red);

    % 1. wrong-side : pred and GT lie in different image halves
    if (odCx <= W/2 && gtX > W/2) || (odCx > W/2 && gtX <= W/2)
        category = 'WrongSide';
    else
        % 2. lesion-bound : pred falls on lesion/exudate area
        if odCx >= 1 && odCx <= W && odCy >= 1 && odCy <= H && ...
                dbg.exudateMask(odCy, odCx)
            category = 'LesionBound';
        else
            % Distance-from-GT-but-still-same-side
            if err < 80
                category = 'SlightOff';
            else
                category = 'Other';
            end
        end
    end

    failures(end+1, :) = {baseName, err, odCx, odCy, gtX, gtY, category};
    fprintf('  Failure: %s err=%.1f cat=%s\n', baseName, err, category);
end

if isempty(failures)
    fprintf('No failures found.\n');
    return;
end

% --- Counts ---
cats = failures(:, 7);
catNames = {'WrongSide', 'LesionBound', 'SlightOff', 'Other'};
counts   = zeros(1, numel(catNames));
for c = 1:numel(catNames)
    counts(c) = sum(strcmp(cats, catNames{c}));
end

fprintf('\n===== FAILURE CATEGORIES =====\n');
for c = 1:numel(catNames)
    fprintf('  %-13s : %d\n', catNames{c}, counts(c));
end
fprintf('  Total failures: %d / %d\n', sum(counts), N);

% --- CSV ---
T = table( ...
    string({failures{:,1}})', ...
    cell2mat(failures(:,2)), ...
    cell2mat(failures(:,3)), ...
    cell2mat(failures(:,4)), ...
    cell2mat(failures(:,5)), ...
    cell2mat(failures(:,6)), ...
    string({failures{:,7}})', ...
    'VariableNames', {'ImageName','Error_px','PredX','PredY','GT_X','GT_Y','Category'});
T = sortrows(T, 'Error_px', 'descend');
csvPath = fullfile(outDir, 'failure_classification.csv');
writetable(T, csvPath);
fprintf('Saved CSV to: %s\n', csvPath);

% --- Pie chart of categories ---
fig = figure('Visible','off','Position',[50 50 700 600],'Color','w');
keep = counts > 0;
labelsList = catNames(keep);
keptCounts = counts(keep);
labels = cell(1, sum(keep));
for k = 1:numel(labelsList)
    labels{k} = sprintf('%s (%d)', labelsList{k}, keptCounts(k));
end
colormap([0.83 0.18 0.18; 0.96 0.65 0.14; 0.20 0.55 0.85; 0.55 0.55 0.55]);
pie(keptCounts, labels);
title(sprintf('OD Localization Failure Categories (Total: %d / %d)', sum(counts), N), ...
      'FontSize', 13, 'FontWeight', 'bold');
try
    exportgraphics(fig, fullfile(figDir, 'F1_failure_pie.png'), 'Resolution', 130, 'BackgroundColor','white');
catch
    saveas(fig, fullfile(figDir, 'F1_failure_pie.png'));
end
close(fig);
fprintf('Saved: F1_failure_pie.png\n');

% --- Visualize one example from each category ---
% Pick a representative failure per category (largest error within category)
for c = 1:numel(catNames)
    catName = catNames{c};
    idxC = find(strcmp(cats, catName));
    if isempty(idxC); continue; end

    % Largest error in this category
    [~, maxIdx] = max(cell2mat(failures(idxC, 2)));
    f = failures(idxC(maxIdx), :);

    name = f{1};
    imgPath = fullfile(testImgDir, [name '.jpg']);
    img     = imread(imgPath);
    img512  = imresize(img, [512 512]);
    pre     = preprocessFundusImage(img);
    [odCx, odCy, dbg] = detectOpticDiscCenter(pre);

    fig = figure('Visible','off','Position',[50 50 1500 900],'Color','w');

    subplot(2,3,1);
    imshow(img512); hold on;
    plot(odCx, odCy, 'r+', 'MarkerSize', 22, 'LineWidth', 3);
    plot(f{5}, f{6}, 'go', 'MarkerSize', 18, 'LineWidth', 3);
    legend({'Predicted','GT'}, 'Location','northeast', 'FontSize', 11);
    title(sprintf('%s   err=%.1f px   [%s]', name, f{2}, catName), ...
          'FontSize', 12, 'FontWeight', 'bold', 'Interpreter','none');

    subplot(2,3,2);
    imshow(dbg.brightMap, []); colormap(gca, 'hot');
    title('brightMap');

    subplot(2,3,3);
    imshow(dbg.brightCandidates); hold on;
    plot(odCx, odCy, 'r+', 'MarkerSize', 18, 'LineWidth', 2);
    plot(f{5}, f{6}, 'go', 'MarkerSize', 14, 'LineWidth', 2);
    title('brightCandidates + Pred / GT');

    subplot(2,3,4);
    imshow(dbg.vesselDensity, []); colormap(gca, 'hot');
    title('vesselDensity');

    subplot(2,3,5);
    imshow(dbg.exudateMask);
    title('exudateMask (lesion-like)');

    subplot(2,3,6);
    imshow(dbg.scoreMap, []); colormap(gca, 'hot'); hold on;
    plot(odCx, odCy, 'g+', 'MarkerSize', 22, 'LineWidth', 3);
    plot(f{5}, f{6}, 'co', 'MarkerSize', 16, 'LineWidth', 2.5);
    title('scoreMap + Pred (g+) / GT (co)');

    sgtitle(sprintf('Failure case [%s] - %s (err = %.1f px)', catName, name, f{2}), ...
            'FontSize', 14, 'FontWeight', 'bold', 'Interpreter','none');

    outPng = fullfile(figDir, sprintf('F2_failure_%s_%s.png', catName, name));
    try
        exportgraphics(fig, outPng, 'Resolution', 130, 'BackgroundColor','white');
    catch
        saveas(fig, outPng);
    end
    close(fig);
    fprintf('Saved: %s\n', outPng);
end
fprintf('\nFailure analysis complete.\n');

end
