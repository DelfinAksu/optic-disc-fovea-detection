function generateIPFigures(projectRoot)
%GENERATEIPFIGURES  Step-by-step image processing visualizations for the report.
%
% Generates 30 PNG figures, one per IP technique, for a single example image
% (IDRiD_55). Saves them to:
%
%   <projectRoot>/results/report_figures/pipeline_steps/
%     01_preprocessing/   01..05.png
%     02_od_detection/    06..18.png
%     03_fovea_detection/ 19..24.png
%     04_od_segmentation/ 25..30.png
%
% Run from anywhere — the script auto-detects the project root from its own
% file location (script lives in <projectRoot>/scripts/).
%
%     >> generateIPFigures
%
% This is a self-contained script: it inlines all preprocessing and pipeline
% steps so every intermediate image is available for visualization.

%% Auto-detect project root (script lives in <projectRoot>/scripts/)
if nargin < 1 || isempty(projectRoot)
    scriptPath  = mfilename('fullpath');
    if isempty(scriptPath)
        projectRoot = pwd;
    else
        scriptDir   = fileparts(scriptPath);
        projectRoot = fileparts(scriptDir);
    end
end
addpath(genpath(fullfile(projectRoot, 'src')));
fprintf('Project root: %s\n', projectRoot);

%% Paths
exampleImg = fullfile(projectRoot, 'data', 'raw', 'A.Segmentation', ...
                      'images', 'test', 'IDRiD_55.jpg');
exampleGT  = fullfile(projectRoot, 'data', 'raw', 'A.Segmentation', ...
                      'masks',  'test', 'IDRiD_55_OD.tif');

outBase = fullfile(projectRoot, 'results', 'report_figures', 'pipeline_steps');
cats = struct( ...
    'p', '01_preprocessing', ...
    'd', '02_od_detection', ...
    'f', '03_fovea_detection', ...
    's', '04_od_segmentation');

if exist(outBase, 'dir')
    rmdir(outBase, 's');
end
fn = fieldnames(cats);
for i = 1:numel(fn)
    mkdir(fullfile(outBase, cats.(fn{i})));
end

%% Style constants for readable figures
TITLE_FONT  = 12;
SGTITLE_FONT = 14;
AXIS_FONT   = 10;

% Default figure style
set(0, 'DefaultFigureColor', 'w');
set(0, 'DefaultAxesFontSize', AXIS_FONT);
set(0, 'DefaultAxesTitleFontSizeMultiplier', 1.0);
set(0, 'DefaultAxesTitleFontWeight', 'bold');
set(0, 'DefaultTextColor', 'k');

% Helper: set every subplot title to dark, readable text
    function styleAllTitles(figHandle)
        ax = findall(figHandle, 'Type', 'axes');
        for ai = 1:numel(ax)
            t = get(ax(ai), 'Title');
            if ~isempty(t)
                set(t, 'Color', 'k', 'FontWeight', 'bold', ...
                       'FontSize', TITLE_FONT, ...
                       'BackgroundColor', 'none');
            end
        end
    end

% Helper: save figure as PNG and close
    function saveAndClose(cat, name, fig)
        styleAllTitles(fig);
        outPath = fullfile(outBase, cats.(cat), [name '.png']);
        try
            exportgraphics(fig, outPath, 'Resolution', 130, ...
                           'BackgroundColor', 'white');
        catch
            saveas(fig, outPath);
        end
        close(fig);
        fprintf('  saved: %s\n', outPath);
    end

% Helper for 'sgtitle' with consistent style
    function setSGT(fig, txt)
        sgtitle(fig, txt, 'FontSize', SGTITLE_FONT, 'FontWeight', 'bold', ...
                'Color', 'k');
    end

%% Load example image
fprintf('Loading %s...\n', exampleImg);
imgOrig = imread(exampleImg);
img512  = imresize(imgOrig, [512 512]);
[H, W, ~] = size(img512);

maskGT     = imread(exampleGT) > 0;
maskGT512  = imresize(maskGT, [512 512], 'nearest') > 0;

%% =========================================================
%  CATEGORY 1: PREPROCESSING
%  =========================================================
fprintf('\n=== Category 1: Preprocessing ===\n');

redRaw   = im2double(img512(:,:,1));
greenRaw = im2double(img512(:,:,2));
blueRaw  = im2double(img512(:,:,3));

% --- 01: Original ---
fig = figure('Visible','off','Position',[50 50 600 600],'Color','w');
imshow(img512);
title('Original Fundus Image (512x512) - IDRiD_55','Interpreter','none');
saveAndClose('p','01_original_rgb',fig);

% --- 02: Channel separation ---
fig = figure('Visible','off','Position',[50 50 1600 420],'Color','w');
subplot(1,4,1); imshow(img512); title('RGB');
subplot(1,4,2); imshow(redRaw,[0 1]);   title({'Red Channel','(brightness information)'});
subplot(1,4,3); imshow(greenRaw,[0 1]); title({'Green Channel','(vessel contrast)'});
subplot(1,4,4); imshow(blueRaw,[0 1]);  title({'Blue Channel','(low SNR - not used)'});
setSGT(fig,'IP Technique: Color Channel Separation');
saveAndClose('p','02_channel_separation',fig);

% --- 03: CLAHE with histograms ---
redClahe   = adapthisteq(redRaw);
greenClahe = adapthisteq(greenRaw);

fig = figure('Visible','off','Position',[50 50 1400 900],'Color','w');
subplot(2,3,1); imshow(greenRaw,[]);   title({'Green Channel','(before CLAHE)'});
subplot(2,3,2); imshow(greenClahe,[]); title({'Green Channel','(after CLAHE)'});
subplot(2,3,3);
histogram(greenRaw(:),64,'FaceColor',[0.5 0.5 0.5],'FaceAlpha',0.5,'EdgeColor','none'); hold on;
histogram(greenClahe(:),64,'FaceColor',[0 0.6 0],'FaceAlpha',0.5,'EdgeColor','none');
legend('Before','After','Location','northeast'); title('Green Histogram'); grid on;
xlabel('intensity'); ylabel('count');

subplot(2,3,4); imshow(redRaw,[]);   title({'Red Channel','(before CLAHE)'});
subplot(2,3,5); imshow(redClahe,[]); title({'Red Channel','(after CLAHE)'});
subplot(2,3,6);
histogram(redRaw(:),64,'FaceColor',[0.5 0.5 0.5],'FaceAlpha',0.5,'EdgeColor','none'); hold on;
histogram(redClahe(:),64,'FaceColor',[0.7 0 0],'FaceAlpha',0.5,'EdgeColor','none');
legend('Before','After','Location','northeast'); title('Red Histogram'); grid on;
xlabel('intensity'); ylabel('count');

setSGT(fig,'IP Technique: CLAHE (Contrast Limited Adaptive Histogram Equalization)');
saveAndClose('p','03_clahe_with_histograms',fig);

% --- 04: Gaussian smoothing (effect of sigma) ---
sigmas = [0 2 6 12];
fig = figure('Visible','off','Position',[50 50 1600 470],'Color','w');
for i = 1:4
    if sigmas(i) == 0
        imgS = greenClahe;
        ttl  = '\sigma = 0  (original)';
    else
        imgS = imgaussfilt(greenClahe, sigmas(i));
        ttl  = sprintf('\\sigma = %d', sigmas(i));
    end
    subplot(1,4,i); imshow(imgS,[0 1]); title(ttl);
end
setSGT(fig,'IP Technique: Gaussian Smoothing - Effect of \sigma (Green Channel)');
saveAndClose('p','04_gaussian_smoothing',fig);

% Final preprocessed channels
red   = imgaussfilt(redClahe,   6);
green = imgaussfilt(greenClahe, 6);

% --- 05: Unsharp mask ---
greenBlur  = imgaussfilt(green, 2);
greenSharp = max(0, min(1, green + 1.5*(green - greenBlur)));

fig = figure('Visible','off','Position',[50 50 1600 470],'Color','w');
subplot(1,4,1); imshow(green,[]);     title({'Smoothed Green','(CLAHE+Gauss \sigma=6)'});
subplot(1,4,2); imshow(greenBlur,[]); title({'Further Blurred','(extra \sigma=2)'});
subplot(1,4,3); imshow(abs(green-greenBlur),[]); colormap(gca,'gray');
                title({'High Frequencies','= Green - Blur'});
subplot(1,4,4); imshow(greenSharp,[]); title({'Unsharp Mask Result','= Green + 1.5\times(Green-Blur)'});
setSGT(fig,'IP Technique: Unsharp Masking - Recovering Vessel Detail');
saveAndClose('p','05_unsharp_mask',fig);

%% =========================================================
%  CATEGORY 2: OD DETECTION
%  =========================================================
fprintf('\n=== Category 2: OD Detection ===\n');

% --- 06: Field mask construction ---
maskThr    = red > 0.05;
maskFilled = imfill(maskThr, 'holes');
maskClean  = bwareaopen(maskFilled, 5000);
fieldMask  = maskClean;

fig = figure('Visible','off','Position',[50 50 1600 470],'Color','w');
subplot(1,4,1); imshow(red,[]);     title('Preprocessed Red');
subplot(1,4,2); imshow(maskThr);    title({'Step 1: red > 0.05','(Thresholding)'});
subplot(1,4,3); imshow(maskFilled); title({'Step 2: imfill','(Fill holes)'});
subplot(1,4,4); imshow(maskClean);  title({'Step 3: bwareaopen','(Remove small objects)'});
setSGT(fig,'IP Technique: Field Mask Construction - 3 Sequential Morphological Steps');
saveAndClose('d','06_field_mask_construction',fig);

% --- 07: Multi-scale brightness maps ---
brightMap    = mat2gray(imgaussfilt(red, 16));
brightStrong = mat2gray(imgaussfilt(red,  8));

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(red,[]); title({'Red Channel','(preprocessed)'});
subplot(1,3,2); imshow(brightStrong,[]); colormap(gca,'hot'); colorbar;
                title({'brightStrong = Gauss(red, \sigma=8)','(more local)'});
subplot(1,3,3); imshow(brightMap,[]);    colormap(gca,'hot'); colorbar;
                title({'brightMap = Gauss(red, \sigma=16)','(broad illumination)'});
setSGT(fig,'IP Technique: Multi-Scale Gaussian - Different \sigma at Different Scales');
saveAndClose('d','07_brightness_multiscale',fig);

% --- 08: Adaptive percentile threshold ---
fieldVals  = brightMap(fieldMask);
sortedVals = sort(fieldVals);
threshold  = sortedVals(round(0.95 * numel(sortedVals)));

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(brightMap,[]); colormap(gca,'hot'); colorbar; title('brightMap');
subplot(1,3,2);
histogram(fieldVals,50,'FaceColor',[0.27 0.51 0.71]); hold on;
xline(threshold,'r','LineWidth',2,'Label',sprintf('95%%-tile = %.3f',threshold), ...
      'LabelVerticalAlignment','top','Color','r','FontSize',10,'FontWeight','bold');
title({'brightMap Histogram (within field)','+ Adaptive Threshold'});
xlabel('brightMap value'); ylabel('count'); grid on;
subplot(1,3,3); imshow(brightMap >= threshold);
                title({sprintf('brightMap \\geq %.3f',threshold),'(top 5%)'});
setSGT(fig,'IP Technique: Adaptive Percentile Thresholding (image-dependent)');
saveAndClose('d','08_adaptive_threshold',fig);

% --- 09: Bright candidates cleanup ---
brightThr   = (brightMap >= threshold) & fieldMask;
brightOpen  = imopen(brightThr, strel('disk',3));
brightClean = bwareaopen(brightOpen, 200);
brightCandidates = brightClean;

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(brightThr);   title({'Step 1: Threshold','+ field mask AND'});
subplot(1,3,2); imshow(brightOpen);  title({'Step 2: imopen(disk 3)','(break thin bridges)'});
subplot(1,3,3); imshow(brightClean); title({'Step 3: bwareaopen(200)','(remove small lesions)'});
setSGT(fig,'IP Technique: Morphological Opening - Cleaning Bright Candidates');
saveAndClose('d','09_bright_candidates_cleanup',fig);

% --- 10: Multi-orientation bottom-hat (4 angles) ---
anglesShow = [0 45 90 135];
fig = figure('Visible','off','Position',[50 50 1600 820],'Color','w');
for i = 1:4
    se = strel('line', 21, anglesShow(i));
    bothatA = imbothat(greenSharp, se);
    nh = se.Neighborhood;
    subplot(2,4,i);   imshow(nh,'InitialMagnification','fit');
                     title(sprintf('SE: line, length=21,\nangle=%d', anglesShow(i)));
    subplot(2,4,i+4); imshow(mat2gray(bothatA),[]);
                     title('Bottom-hat output');
end
setSGT(fig,'IP Technique: Multi-Orientation Bottom-Hat - Captures Different Vessel Directions');
saveAndClose('d','10_multi_orientation_bothat',fig);

% --- 11: Final vesselResponse ---
vesselResponse = zeros(H,W);
for a = 0:15:165
    se = strel('line', 21, a);
    vesselResponse = max(vesselResponse, imbothat(greenSharp, se));
end
vesselResponse = mat2gray(vesselResponse);

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(greenSharp,[]); title({'Green Sharp','(after unsharp mask)'});
subplot(1,3,2); imshow(vesselResponse,[]);
                title({'vesselResponse =','max_\theta Bothat(green sharp, SE_\theta)'});
subplot(1,3,3); imshowpair(greenSharp, vesselResponse, 'blend');
                title({'Blended overlay','(vessels prominent)'});
setSGT(fig,'IP Technique: Bottom-hat Maximum Across Orientations - Direction-Independent Vessel Response');
saveAndClose('d','11_vessel_response_final',fig);

% --- 12: Otsu threshold ---
otsuT = graythresh(vesselResponse);
vesselMap = bwareaopen(imbinarize(vesselResponse, otsuT), 30) & fieldMask;

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(vesselResponse,[]); title('vesselResponse');
subplot(1,3,2);
histogram(vesselResponse(:),64,'FaceColor',[0.27 0.51 0.71]); hold on;
xline(otsuT,'r','LineWidth',2,'Label',sprintf('Otsu = %.3f',otsuT), ...
      'LabelVerticalAlignment','top','Color','r','FontSize',10,'FontWeight','bold');
title('vesselResponse Histogram + Otsu Threshold');
xlabel('vessel response'); ylabel('count'); grid on;
subplot(1,3,3); imshow(vesselMap); title({'Binary Vessel Map','(Otsu + bwareaopen)'});
setSGT(fig,'IP Technique: Otsu Thresholding - Automatic Bimodal Threshold');
saveAndClose('d','12_otsu_vessel_binary',fig);

% --- 13: Vessel density (disk-kernel convolution) ---
odKernel      = fspecial('disk', 40);
vesselDensity = mat2gray(imfilter(double(vesselMap), odKernel, 'replicate'));

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(vesselMap); title('Binary Vessel Map');
subplot(1,3,2); imshow(odKernel,[]); title({'Disk Kernel (r=40)','(matches OD size)'});
subplot(1,3,3); imshow(vesselDensity,[]); colormap(gca,'hot'); colorbar;
                title({'vesselDensity =','VesselMap \ast DiskKernel'});
setSGT(fig,'IP Technique: Disk-Kernel Convolution - Regional Vessel Density');
saveAndClose('d','13_vessel_density_convolution',fig);

% --- 14: Top-hat for exudates / lesion penalty ---
exudateResponse = imtophat(red, strel('disk', 8));
exudateMask     = bwareaopen((exudateResponse > 0.10) & (vesselDensity < 0.20), 30);
lesionPenalty   = mat2gray(imgaussfilt(double(exudateMask), 10));

fig = figure('Visible','off','Position',[50 50 1600 470],'Color','w');
subplot(1,4,1); imshow(red,[]);            title('Preprocessed Red');
subplot(1,4,2); imshow(exudateResponse,[]); colormap(gca,'hot');
                title({'Top-hat = Red - Open(Red, disk 8)','(small bright structures)'});
subplot(1,4,3); imshow(exudateMask);
                title({'exudateMask = TopHat>0.1 &','vesselDensity<0.2'});
subplot(1,4,4); imshow(lesionPenalty,[]); colormap(gca,'hot');
                title({'lesionPenalty','(Gauss \sigma=10 smoothing)'});
setSGT(fig,'IP Technique: White Top-Hat - Extract Small Bright Structures (Lesions)');
saveAndClose('d','14_tophat_lesion_penalty',fig);

% --- 15: Anatomical horizontal band prior ---
[~, Y]              = meshgrid(1:W, 1:H);
distFromCenterY     = abs(Y - H/2) / (H/2);
horizontalBandPrior = mat2gray(exp(-(distFromCenterY.^2) / (2 * 0.25^2)));

fig = figure('Visible','off','Position',[50 50 1100 470],'Color','w');
subplot(1,2,1); imshow(horizontalBandPrior,[]); colormap(gca,'hot'); colorbar;
                title({'Horizontal Band Prior','Gauss(distance from y center, \sigma=0.25H)'});
subplot(1,2,2);
plot(horizontalBandPrior(:, round(W/2)), 1:H, 'b','LineWidth',2);
set(gca,'YDir','reverse'); grid on;
title('Vertical Profile (middle column)'); xlabel('prior value'); ylabel('y');
setSGT(fig,'IP Technique: Spatial Prior - Anatomical Gaussian Map');
saveAndClose('d','15_anatomical_prior',fig);

% --- 16: Score map fusion ---
scoreMap = ...
    0.40 * brightMap + ...
    0.20 * brightStrong + ...
    0.30 * vesselDensity + ...
    0.15 * horizontalBandPrior - ...
    0.30 * lesionPenalty;
scoreMap = max(scoreMap, 0);
scoreMap(~fieldMask) = 0;
scoreMap = mat2gray(scoreMap);

components = {brightMap,'0.40 \times brightMap'; ...
              brightStrong,'0.20 \times brightStrong'; ...
              vesselDensity,'0.30 \times vesselDensity'; ...
              horizontalBandPrior,'0.15 \times horizontalBand'; ...
              lesionPenalty,'-0.30 \times lesionPenalty'; ...
              scoreMap,'TOTAL scoreMap'};

fig = figure('Visible','off','Position',[50 50 1500 1000],'Color','w');
for k = 1:6
    subplot(2,3,k); imshow(components{k,1},[]); colormap(gca,'hot');
    title(components{k,2});
end
setSGT(fig,'IP Technique: Weighted Sum Fusion - Combining Multiple Feature Maps');
saveAndClose('d','16_score_map_fusion',fig);

% --- 17: Connected component selection ---
cc = bwconncomp(brightCandidates);
nComp = cc.NumObjects;
L = labelmatrix(cc);
ccColored = label2rgb(L, 'parula', 'k', 'shuffle');

bestK = 0; bestScore = -Inf; odCx = round(W/2); odCy = round(H/2);
for k = 1:nComp
    pix = cc.PixelIdxList{k};
    s = scoreMap(pix); area = numel(pix);
    sb = 1 + 0.3 * min(area/2000, 1);
    fs = mean(s) * sb;
    if fs > bestScore
        bestScore = fs;
        [yIdx, xIdx] = ind2sub([H, W], pix);
        ws = sum(s);
        if ws > 0
            odCx = round(sum(xIdx .* s) / ws);
            odCy = round(sum(yIdx .* s) / ws);
        end
        bestK = k;
    end
end

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(brightCandidates);
                title(sprintf('brightCandidates (%d connected components)',nComp));
subplot(1,3,2); imshow(ccColored);
                title({'Colored CC labeling','(each component a different color)'});
subplot(1,3,3);
imshow(img512); hold on;
overlay = (L == bestK);
visboundaries(overlay, 'Color', 'g', 'LineWidth', 2);
plot(odCx, odCy, 'r+', 'MarkerSize', 22, 'LineWidth', 3);
title({sprintf('Best-scoring component (score=%.3f)',bestScore),'+ OD center (red)'});
setSGT(fig,'IP Technique: Connected Component Analysis + Score-weighted Center of Mass');
saveAndClose('d','17_connected_components',fig);

% --- 18: Final OD center ---
fig = figure('Visible','off','Position',[50 50 800 800],'Color','w');
imshow(img512); hold on;
plot(odCx, odCy, 'r+', 'MarkerSize', 30, 'LineWidth', 4);
legend(sprintf('Detected OD (%d, %d)', odCx, odCy), 'Location','northeast', 'FontSize', 11);
title(sprintf('Final OD Detection: (%d, %d)', odCx, odCy));
saveAndClose('d','18_final_od_center',fig);

fprintf('  Detected OD: (%d, %d)\n', odCx, odCy);

%% =========================================================
%  CATEGORY 3: FOVEA DETECTION
%  =========================================================
fprintf('\n=== Category 3: Fovea Detection ===\n');

DX = 152; DY = 25;
if odCx < W/2
    expectedX = odCx + DX;
else
    expectedX = odCx - DX;
end
expectedY = odCy + DY;

boxR = 70;
sMin = max(1, round(expectedX - boxR)); sMax = min(W, round(expectedX + boxR));
yMin = max(1, round(expectedY - boxR)); yMax = min(H, round(expectedY + boxR));

% --- 19: Anatomical prior + search box ---
fig = figure('Visible','off','Position',[50 50 800 800],'Color','w');
imshow(img512); hold on;
plot(odCx, odCy, 'r+', 'MarkerSize', 22, 'LineWidth', 3);
plot(expectedX, expectedY, 'b+', 'MarkerSize', 22, 'LineWidth', 3);
rectangle('Position',[sMin, yMin, sMax-sMin, yMax-yMin], ...
          'EdgeColor','c', 'LineWidth', 3);
legend({'OD center','Expected fovea (\pm 152, +25)','Search box'}, ...
       'Location','southwest', 'FontSize', 11);
title('Anatomical Prior: Fovea is 152 px temporal + 25 px below OD');
saveAndClose('f','19_anatomical_prior_for_fovea',fig);

% --- 20: Field erosion ---
fieldErod = imerode(fieldMask, strel('square', 35));

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(fieldMask); title('Original Field Mask');
subplot(1,3,2); imshow(fieldErod); title({'Erode (35x35 square)','(17 px in from edge)'});
diffMask = double(fieldMask) - double(fieldErod);
subplot(1,3,3); imshow(diffMask,[]); colormap(gca, 'hot');
                title({'Erosion Difference','(vignette protection)'});
setSGT(fig,'IP Technique: Morphological Erosion - Removing Edge Pixels');
saveAndClose('f','20_field_erosion',fig);

% --- 21: Darkness map ---
darkMap = mat2gray(imgaussfilt(1 - red, 8));

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(red,[]);     title('Preprocessed Red');
subplot(1,3,2); imshow(1 - red,[]); title('1 - Red (invert)');
subplot(1,3,3); imshow(darkMap,[]); title({'darkMap = Gauss(1-Red, \sigma=8)','(fovea = darkest region)'});
setSGT(fig,'IP Technique: Image Inversion + Smoothing - Fovea is the Darkest Region');
saveAndClose('f','21_darkness_map',fig);

% --- 22: Distance prior ---
[Xg, Yg] = meshgrid(1:W, 1:H);
distExp = sqrt((Xg - expectedX).^2 + (Yg - expectedY).^2);
distancePrior = mat2gray(exp(-(distExp.^2) / (2 * 40^2)));

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(distExp,[]); colormap(gca,'gray');
                title({'Distance Map','sqrt((x-eX)^2 + (y-eY)^2)'});
subplot(1,3,2); imshow(distancePrior,[]); colormap(gca,'hot');
                title({'Distance Prior =','exp(-d^2/(2 \cdot 40^2))'});
subplot(1,3,3);
imshow(img512); hold on;
h = imshow(distancePrior); set(h, 'AlphaData', 0.5);
plot(expectedX, expectedY, 'b+', 'MarkerSize', 20, 'LineWidth', 3);
title({'Overlay - high values','around expected fovea'});
setSGT(fig,'IP Technique: Spatial Gaussian Distance Prior');
saveAndClose('f','22_distance_prior',fig);

% --- 23: Combined fovea score ---
foveaScore = max(0.45 * darkMap + 0.55 * distancePrior, 0);
maskSearch = false(H, W);
maskSearch(yMin:yMax, sMin:sMax) = true;
maskSearch = maskSearch & fieldErod;
foveaScore(~maskSearch) = 0;

[~, idx] = max(foveaScore(:));
[fovCy, fovCx] = ind2sub([H, W], idx);

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(0.45*darkMap,[]); colormap(gca,'hot'); title('0.45 \times darkMap');
subplot(1,3,2); imshow(0.55*distancePrior,[]); colormap(gca,'hot'); title('0.55 \times distancePrior');
subplot(1,3,3); imshow(foveaScore,[]); colormap(gca,'hot'); hold on;
plot(fovCx, fovCy, 'g+', 'MarkerSize', 22, 'LineWidth', 3);
title({'Combined fovea score',sprintf('+ Final fovea = (%d, %d)',fovCx,fovCy)});
setSGT(fig,'IP Technique: Score Fusion and Argmax (within search window)');
saveAndClose('f','23_fovea_score_argmax',fig);

% --- 24: Final OD + fovea on RGB ---
fig = figure('Visible','off','Position',[50 50 800 800],'Color','w');
imshow(img512); hold on;
plot(odCx, odCy, 'r+', 'MarkerSize', 25, 'LineWidth', 3.5);
plot(fovCx, fovCy, 'g+', 'MarkerSize', 25, 'LineWidth', 3.5);
legend({sprintf('OD (%d, %d)',odCx,odCy), sprintf('Fovea (%d, %d)',fovCx,fovCy)}, ...
       'Location','northeast', 'FontSize', 11);
title('Final: OD + Fovea Detection');
saveAndClose('f','24_final_od_fovea',fig);

%% =========================================================
%  CATEGORY 4: OD SEGMENTATION
%  =========================================================
fprintf('\n=== Category 4: OD Segmentation ===\n');

% --- 25: ROI extraction ---
roiR = 80;
x1 = max(1, odCx - roiR); x2 = min(W, odCx + roiR);
y1 = max(1, odCy - roiR); y2 = min(H, odCy + roiR);
roiRed  = red(y1:y2, x1:x2);
roiVMap = vesselMap(y1:y2, x1:x2);

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(red,[]); hold on;
rectangle('Position',[x1 y1 x2-x1 y2-y1],'EdgeColor','r','LineWidth',3);
plot(odCx, odCy, 'r+', 'MarkerSize',15,'LineWidth',2);
title('ROI Selection (160x160 around OD)');
subplot(1,3,2); imshow(roiRed,[]); title('ROI: Red Channel');
subplot(1,3,3); imshow(roiVMap); title({'ROI: Vessel Mask','(used for inpainting)'});
setSGT(fig,'IP Technique: ROI Extraction - 160x160 Region Around OD Center');
saveAndClose('s','25_roi_extraction',fig);

% --- 26: Inpainting ---
roiVDilated = imdilate(roiVMap, strel('disk',3));
try
    roiInpainted = inpaintCoherent(roiRed, roiVDilated);
catch
    closed = imclose(roiRed, strel('disk',5));
    roiInpainted = roiRed;
    roiInpainted(roiVDilated) = closed(roiVDilated);
end

fig = figure('Visible','off','Position',[50 50 1600 470],'Color','w');
subplot(1,4,1); imshow(roiRed,[]);      title({'ROI Red','(vessels are dark valleys)'});
subplot(1,4,2); imshow(roiVDilated);    title('Vessel Mask (dilated)');
subplot(1,4,3); imshow(roiInpainted,[]); title({'Inpainted','(vessel pixels filled)'});
subplot(1,4,4); imshow(abs(roiInpainted - roiRed),[]); colormap(gca,'hot');
                title({'Difference','(only vessel area)'});
setSGT(fig,'IP Technique: Inpainting - Removing Vessel Artifacts');
saveAndClose('s','26_telea_inpainting',fig);

% --- 27: Otsu + percentile threshold ---
otsuTRoi = graythresh(roiInpainted);
pctTRoi  = quantile(roiInpainted(:), 0.78);
segThr   = max(otsuTRoi, pctTRoi);
roiThresh = roiInpainted > segThr;

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(roiInpainted,[]); title('Inpainted ROI');
subplot(1,3,2);
histogram(roiInpainted(:),50,'FaceColor',[0.27 0.51 0.71]); hold on;
xline(otsuTRoi,'r','LineWidth',2);
xline(pctTRoi, 'g','LineWidth',2);
xline(segThr,  'k--','LineWidth',3);
legend({'histogram', sprintf('Otsu = %.3f',otsuTRoi), ...
        sprintf('78%%-tile = %.3f',pctTRoi), sprintf('Final = %.3f',segThr)}, ...
       'Location','northwest', 'FontSize',10);
title('ROI Histogram + 3 Thresholds');
xlabel('intensity'); ylabel('count'); grid on;
subplot(1,3,3); imshow(roiThresh); title({'Threshold result','(ROI > final)'});
setSGT(fig,'IP Technique: Otsu + Percentile - Adaptive Threshold Combination');
saveAndClose('s','27_otsu_percentile_threshold',fig);

% --- 28: Morphological cleanup ---
roiClose  = imclose(roiThresh, strel('disk',7));
roiFilled = imfill(roiClose, 'holes');
roiOpen   = imopen(roiFilled, strel('disk',4));

fig = figure('Visible','off','Position',[50 50 1600 470],'Color','w');
subplot(1,4,1); imshow(roiThresh); title('After Threshold');
subplot(1,4,2); imshow(roiClose);  title({'imclose(disk 7)','(fill vessel gaps)'});
subplot(1,4,3); imshow(roiFilled); title('imfill(holes)');
subplot(1,4,4); imshow(roiOpen);   title({'imopen(disk 4)','(smooth boundary)'});
setSGT(fig,'IP Technique: Morphological Reconstruction - close \rightarrow fill \rightarrow open');
saveAndClose('s','28_morphology_cleanup',fig);

% --- 29: Connected component selection ---
ccSeg = bwconncomp(roiOpen);
nSeg = ccSeg.NumObjects;
LSeg = labelmatrix(ccSeg);

centerXroi = odCx - x1 + 1;
centerYroi = odCy - y1 + 1;

bestK = 0; bestD = Inf;
for k = 1:nSeg
    [yIdx, xIdx] = ind2sub(size(roiOpen), ccSeg.PixelIdxList{k});
    cx = mean(xIdx); cy = mean(yIdx);
    d = sqrt((cx - centerXroi)^2 + (cy - centerYroi)^2);
    if d < bestD; bestD = d; bestK = k; end
end

odMaskRoi = (LSeg == bestK);
odMaskRoi = imclose(odMaskRoi, strel('disk',3));
odMaskRoi = imfill(odMaskRoi, 'holes');

ccSegColored = label2rgb(LSeg, 'parula', 'k', 'shuffle');

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(ccSegColored); hold on;
plot(centerXroi, centerYroi, 'r+', 'MarkerSize',18,'LineWidth',2);
title({sprintf('Connected components (%d)',nSeg),'+ OD center (red)'});
subplot(1,3,2); imshow(odMaskRoi); title({'Selected component','(closest to center)'});
subplot(1,3,3);
imshow(roiInpainted,[]); hold on;
visboundaries(odMaskRoi, 'Color', 'g', 'LineWidth', 2);
title('Overlaid on ROI');
setSGT(fig,'IP Technique: Connected Component + Closest-to-Center Selection');
saveAndClose('s','29_segmentation_cc_selection',fig);

% --- 30: Final mask vs GT ---
odMaskFull = false(H, W);
odMaskFull(y1:y2, x1:x2) = odMaskRoi;

inter = nnz(odMaskFull & maskGT512);
sumP  = nnz(odMaskFull);
sumG  = nnz(maskGT512);
union = nnz(odMaskFull | maskGT512);
diceVal = 2 * inter / (sumP + sumG + 1e-9);
iouVal  = inter / (union + 1e-9);

fig = figure('Visible','off','Position',[50 50 1400 470],'Color','w');
subplot(1,3,1); imshow(odMaskFull); title('Predicted OD Mask');
subplot(1,3,2); imshow(maskGT512);  title('Ground Truth OD Mask');
subplot(1,3,3);
imshow(img512); hold on;
visboundaries(maskGT512, 'Color', 'r', 'LineWidth', 2.5);
visboundaries(odMaskFull, 'Color', 'g', 'LineWidth', 2.5);
legend({'GT','Pred'},'Location','northeast', 'FontSize', 11);
title(sprintf('Comparison: Dice=%.3f, IoU=%.3f', diceVal, iouVal));
setSGT(fig, sprintf('OD Segmentation Final (IDRiD_55) - Dice=%.3f', diceVal));
saveAndClose('s','30_final_seg_vs_gt',fig);

%% Summary
fprintf('\n=== ALL FIGURES SAVED ===\n');
fprintf('Output directory: %s\n', outBase);
total = 0;
for i = 1:numel(fn)
    p = fullfile(outBase, cats.(fn{i}));
    n = numel(dir(fullfile(p, '*.png')));
    fprintf('  %s: %d figures\n', cats.(fn{i}), n);
    total = total + n;
end
fprintf('Total: %d figures\n', total);
fprintf('\nDetected: OD=(%d,%d) Fovea=(%d,%d)\n', odCx, odCy, fovCx, fovCy);
fprintf('Segmentation: Dice=%.4f IoU=%.4f\n', diceVal, iouVal);

% Restore default figure colors so MATLAB session is left clean
set(0,'DefaultFigureColor','default');
set(0,'DefaultAxesFontSize','default');
set(0,'DefaultAxesTitleFontWeight','default');
set(0,'DefaultTextColor','default');

end
