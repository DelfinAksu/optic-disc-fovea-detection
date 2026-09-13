function demoSingleImage(imgPath)
%DEMOSINGLEIMAGE  Run the complete pipeline on a single retinal image and
%display the optic disc center, fovea center, and OD segmentation boundary.

if nargin < 1 || isempty(imgPath)
    projectRoot = fileparts(mfilename('fullpath'));
    if isempty(projectRoot); projectRoot = pwd; end
    parent = fileparts(projectRoot);
    imgPath = fullfile(parent, 'data', 'raw', 'C.Localization', ...
                       'images', 'test', 'IDRiD_001.jpg');
    if ~exist(imgPath, 'file')
        imgPath = fullfile(projectRoot, 'data', 'raw', 'C.Localization', ...
                           'images', 'test', 'IDRiD_001.jpg');
    end
end

if ~exist(imgPath, 'file')
    error('Image not found: %s', imgPath);
end

[scriptDir, ~] = fileparts(mfilename('fullpath'));
if isempty(scriptDir); scriptDir = pwd; end
projectRoot = fileparts(scriptDir);
if ~exist(fullfile(projectRoot, 'src'), 'dir')
    projectRoot = pwd;
end
addpath(genpath(fullfile(projectRoot, 'src')));

warning('off', 'MATLAB:legend:IgnoringExtraEntries');

% --- Run the full pipeline ---
img = imread(imgPath);
img512 = imresize(img, [512 512]);

pre = preprocessFundusImage(img);
[odCx, odCy, dbg] = detectOpticDiscCenter(pre);
[fvCx, fvCy, ~]   = detectFoveaCenter(pre, odCx, odCy);
odMask            = segmentOpticDisc(pre, odCx, odCy, dbg);

[~, baseName, ~] = fileparts(imgPath);
fprintf('  Image: %s\n', baseName);
fprintf('  OD    center : (%d, %d)\n', odCx, odCy);
fprintf('  Fovea center : (%d, %d)\n', fvCx, fvCy);
fprintf('  OD mask area : %d pixels\n', nnz(odMask));

% --- Display results ---
fig = figure('Color', 'w', 'Position', [100 100 800 800]);
ax = axes(fig);
imshow(img512, 'Parent', ax); hold(ax, 'on');

% OD segmentation boundary in magenta. Mark the boundary objects so they
% are excluded from the legend.
hb = visboundaries(ax, odMask, 'Color', 'm', 'LineWidth', 2);
try
    set(findobj(hb, 'Type', 'Line'), 'HandleVisibility', 'off');
catch
end

% Coordinate markers (these are the only objects that should appear in legend)
hOD  = plot(ax, odCx, odCy, 'r+', 'MarkerSize', 25, 'LineWidth', 3);
hFV  = plot(ax, fvCx, fvCy, 'g+', 'MarkerSize', 25, 'LineWidth', 3);
% Proxy line for the magenta boundary in the legend
hSeg = plot(ax, NaN, NaN, 'm-', 'LineWidth', 2);

% Coordinate labels
text(ax, odCx + 12, odCy, sprintf('[%d, %d]', odCx, odCy), ...
     'Color', 'r', 'FontSize', 11, 'FontWeight', 'bold', ...
     'BackgroundColor', [1 1 1 0.7]);
text(ax, fvCx + 12, fvCy, sprintf('[%d, %d]', fvCx, fvCy), ...
     'Color', [0 0.6 0], 'FontSize', 11, 'FontWeight', 'bold', ...
     'BackgroundColor', [1 1 1 0.7]);

title(ax, sprintf('OD and Fovea Detection - %s', baseName), ...
      'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');

legend(ax, [hOD, hFV, hSeg], ...
       {sprintf('OD center (%d, %d)', odCx, odCy), ...
        sprintf('Fovea center (%d, %d)', fvCx, fvCy), ...
        'OD boundary (segmentation)'}, ...
       'Location', 'southwest', 'FontSize', 10, ...
       'TextColor', 'k', 'Color', 'w');

% --- Save the figure ---
demoDir = fullfile(projectRoot, 'results', 'figures', 'demo');
if ~exist(demoDir, 'dir'); mkdir(demoDir); end
outPng = fullfile(demoDir, [baseName '_demo.png']);
try
    exportgraphics(fig, outPng, 'Resolution', 130, 'BackgroundColor', 'white');
catch
    saveas(fig, outPng);
end

fprintf('  Figure saved: %s\n', outPng);

end
