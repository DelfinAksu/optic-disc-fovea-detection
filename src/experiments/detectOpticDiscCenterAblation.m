function [odCx, odCy, debugInfo] = detectOpticDiscCenterAblation(pre, config)

    if nargin < 2 || isempty(config)
        config = struct();
    end
    config = setDefault(config, 'useUnsharpMask',        true);
    config = setDefault(config, 'useAdaptiveThreshold',  true);
    config = setDefault(config, 'useVesselFeatures',     true);
    config = setDefault(config, 'useLesionPenalty',      true);
    config = setDefault(config, 'useAnatomicalPrior',    true);
    config = setDefault(config, 'ccMode',                'cc');
    config = setDefault(config, 'thresholdPercentile',   0.95);
    config = setDefault(config, 'weightBrightMap',       0.40);
    config = setDefault(config, 'weightBrightStrong',    0.20);
    config = setDefault(config, 'weightVesselDensity',   0.30);
    config = setDefault(config, 'weightLesionPenalty',   0.30);
    config = setDefault(config, 'weightAnatomicalPrior', 0.15);

    red    = pre.red;
    green  = pre.green;
    [H, W] = size(red);

    %% 1. Field mask
    fieldMask = red > 0.05;
    fieldMask = imfill(fieldMask, 'holes');
    fieldMask = bwareaopen(fieldMask, 5000);

    %% 2. Optional unsharp mask on green
    if config.useUnsharpMask
        greenBlur  = imgaussfilt(green, 2);
        greenSharp = green + 1.5 * (green - greenBlur);
        greenSharp = max(0, min(1, greenSharp));
    else
        greenSharp = green;
    end

    %% 3. Brightness maps
    brightMap    = mat2gray(imgaussfilt(red, 16));
    brightStrong = mat2gray(imgaussfilt(red,  8));

    %% 4. Vessel response
    vesselResponse = zeros(H, W);
    angles = 0:15:165;
    for a = angles
        se = strel('line', 21, a);
        vesselResponse = max(vesselResponse, imbothat(greenSharp, se));
    end
    vesselResponse = mat2gray(vesselResponse);

    %% 5. Binary vessel map
    vesselMap = imbinarize(vesselResponse, graythresh(vesselResponse));
    vesselMap = bwareaopen(vesselMap, 30) & fieldMask;

    %% 6. Vessel density
    odKernel      = fspecial('disk', 40);
    vesselDensity = mat2gray(imfilter(double(vesselMap), odKernel, 'replicate'));

    %% 7. Bright candidates - threshold strategy
    if config.useAdaptiveThreshold
        fieldVals = brightMap(fieldMask);
        if isempty(fieldVals)
            threshold = 0.65;
        else
            sortedVals = sort(fieldVals);
            pIdx       = max(1, round(config.thresholdPercentile * numel(sortedVals)));
            threshold  = sortedVals(pIdx);
        end
    else
        threshold = 0.65;
    end

    brightCandidates = (brightMap >= threshold) & fieldMask;
    brightCandidates = imopen(brightCandidates, strel('disk', 3));
    brightCandidates = bwareaopen(brightCandidates, 200);

    %% 8. Lesion penalty
    seSmall         = strel('disk', 8);
    exudateResponse = imtophat(red, seSmall);
    exudateMask     = (exudateResponse > 0.10) & (vesselDensity < 0.20);
    exudateMask     = bwareaopen(exudateMask, 30);
    lesionPenalty   = mat2gray(imgaussfilt(double(exudateMask), 10));

    %% 9. Horizontal-band prior
    [~, Y]              = meshgrid(1:W, 1:H);
    distFromCenterY     = abs(Y - H/2) / (H/2);
    horizontalBandPrior = mat2gray(exp(-(distFromCenterY.^2) / (2 * 0.25^2)));

    %% 10. Score map - resolve weights (boolean toggle overrides numeric weight)
    wB = config.weightBrightMap;
    wS = config.weightBrightStrong;
    wV = config.weightVesselDensity   * config.useVesselFeatures;
    wL = config.weightLesionPenalty   * config.useLesionPenalty;
    wP = config.weightAnatomicalPrior * config.useAnatomicalPrior;

    scoreMap = ...
        wB * brightMap + ...
        wS * brightStrong + ...
        wV * vesselDensity + ...
        wP * horizontalBandPrior - ...
        wL * lesionPenalty;

    scoreMap = max(scoreMap, 0);
    scoreMap(~fieldMask) = 0;
    scoreMap = mat2gray(scoreMap);

    %% 11. Final OD selection
    odCx = round(W/2); odCy = round(H/2);

    switch lower(config.ccMode)

        case 'cc'
            cc = bwconncomp(brightCandidates);
            if cc.NumObjects > 0
                bestScore = -inf;
                for k = 1:cc.NumObjects
                    pix  = cc.PixelIdxList{k};
                    s    = scoreMap(pix);
                    area = numel(pix);
                    sb   = 1 + 0.3 * min(area / 2000, 1);
                    fs   = mean(s) * sb;
                    if fs > bestScore
                        bestScore = fs;
                        [yI, xI] = ind2sub([H, W], pix);
                        ws = sum(s);
                        if ws > 0
                            odCx = round(sum(xI .* s) / ws);
                            odCy = round(sum(yI .* s) / ws);
                        else
                            odCx = round(mean(xI));
                            odCy = round(mean(yI));
                        end
                    end
                end
            else
                [~, idx]     = max(scoreMap(:));
                [odCy, odCx] = ind2sub(size(scoreMap), idx);
            end

        case 'argmax'
            [~, idx]     = max(scoreMap(:));
            [odCy, odCx] = ind2sub(size(scoreMap), idx);

        case 'sumside'
            scoreMap(~brightCandidates) = 0;
            leftSum  = sum(sum(scoreMap(:, 1:round(W/2))));
            rightSum = sum(sum(scoreMap(:, round(W/2)+1:end)));
            sideMask = zeros(H, W);
            if leftSum > rightSum
                sideMask(:, 1:round(W/2)) = 1;
            else
                sideMask(:, round(W/2)+1:end) = 1;
            end
            scoreMap = scoreMap .* sideMask;
            scoreMap = imgaussfilt(scoreMap, 8);
            scoreMap(~fieldMask) = 0;
            [~, idx]     = max(scoreMap(:));
            [odCy, odCx] = ind2sub(size(scoreMap), idx);

        otherwise
            error('Unknown ccMode: %s', config.ccMode);
    end

    %% Debug info
    debugInfo.fieldMask           = fieldMask;
    debugInfo.brightMap           = brightMap;
    debugInfo.brightScore         = brightStrong;
    debugInfo.vesselResponse      = vesselResponse;
    debugInfo.vesselMap           = vesselMap;
    debugInfo.vesselDensity       = vesselDensity;
    debugInfo.lesionPenalty       = lesionPenalty;
    debugInfo.horizontalBandPrior = horizontalBandPrior;
    debugInfo.scoreMap            = scoreMap;
    debugInfo.brightCandidates    = brightCandidates;
    debugInfo.greenSharp          = greenSharp;
    debugInfo.exudateMask         = exudateMask;
    debugInfo.config              = config;

end

function s = setDefault(s, fname, val)
    if ~isfield(s, fname); s.(fname) = val; end
end
