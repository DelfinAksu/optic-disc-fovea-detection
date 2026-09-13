function [odCx, odCy, debugInfo] = detectOpticDiscCenter(pre)

    red   = pre.red;
    green = pre.green;
    [H, W] = size(red);

    %% 1. Field mask
    fieldMask = red > 0.05;
    fieldMask = imfill(fieldMask, 'holes');
    fieldMask = bwareaopen(fieldMask, 5000);

    %% 2. Recover vessel detail lost to preprocessing Gaussian smoothing
    %    Manual unsharp mask (toolbox-free)
    greenBlur  = imgaussfilt(green, 2);
    greenSharp = green + 1.5 * (green - greenBlur);
    greenSharp = max(0, min(1, greenSharp));

    %% 3. Brightness maps
    brightMap    = mat2gray(imgaussfilt(red, 16));   % broad illumination profile
    brightStrong = mat2gray(imgaussfilt(red,  8));   % more local brightness

    %% 4. Vessel response (multi-orientation bottom-hat on sharpened green)
    vesselResponse = zeros(H, W);
    angles = 0:15:165;
    for a = angles
        se = strel('line', 21, a);
        response = imbothat(greenSharp, se);
        vesselResponse = max(vesselResponse, response);
    end
    vesselResponse = mat2gray(vesselResponse);

    %% 5. Binary vessel map
    vesselMap = imbinarize(vesselResponse, graythresh(vesselResponse));
    vesselMap = bwareaopen(vesselMap, 30);
    vesselMap = vesselMap & fieldMask;

    %% 6. Single consolidated vessel-density feature
    %    Disk kernel matched to expected OD size (~80 px diameter @ 512x512)
    odKernel      = fspecial('disk', 40);
    vesselDensity = mat2gray(imfilter(double(vesselMap), odKernel, 'replicate'));

    %% 7. Adaptive bright candidates (top 1% of brightMap inside field mask)
    %    The 99th-percentile threshold was determined by the parameter
    fieldVals = brightMap(fieldMask);
    if isempty(fieldVals)
        threshold = 0.65;
    else
        sortedVals = sort(fieldVals);
        threshold  = sortedVals(round(0.99 * numel(sortedVals)));
    end

    brightCandidates = (brightMap >= threshold) & fieldMask;
    brightCandidates = imopen(brightCandidates, strel('disk', 3));
    brightCandidates = bwareaopen(brightCandidates, 200);

    %% 8. Lesion penalty (top-hat-based, independent of vesselDensity reliability)
    seSmall         = strel('disk', 8);
    exudateResponse = imtophat(red, seSmall);
    exudateMask     = (exudateResponse > 0.10) & (vesselDensity < 0.20);
    exudateMask     = bwareaopen(exudateMask, 30);
    lesionPenalty   = mat2gray(imgaussfilt(double(exudateMask), 10));

    %% 9. Horizontal-band prior (vertical sidePrior removed; CC selection handles it)
    [~, Y] = meshgrid(1:W, 1:H);
    imageCy             = H / 2;
    distFromCenterY     = abs(Y - imageCy) / (H / 2);
    horizontalBandPrior = mat2gray(exp(-(distFromCenterY.^2) / (2 * 0.25^2)));

    %% 10. Score map (no side prior, no vessel entropy)
    scoreMap = ...
        0.40 * brightMap + ...
        0.20 * brightStrong + ...
        0.30 * vesselDensity + ...
        0.15 * horizontalBandPrior - ...
        0.30 * lesionPenalty;

    scoreMap            = max(scoreMap, 0);
    scoreMap(~fieldMask) = 0;
    scoreMap            = mat2gray(scoreMap);

    %% 11. Connected-component selection (replaces broken sum-based side decision)
    odCx = round(W / 2);
    odCy = round(H / 2);

    cc = bwconncomp(brightCandidates);

    if cc.NumObjects > 0
        bestScore = -inf;

        for k = 1:cc.NumObjects
            pixIdx       = cc.PixelIdxList{k};
            scoresInComp = scoreMap(pixIdx);
            compArea     = numel(pixIdx);

            sizeBonus      = 1 + 0.3 * min(compArea / 2000, 1);
            compFinalScore = mean(scoresInComp) * sizeBonus;

            if compFinalScore > bestScore
                bestScore = compFinalScore;

                [yIdx, xIdx] = ind2sub([H, W], pixIdx);
                wsum         = sum(scoresInComp);
                if wsum > 0
                    odCx = round(sum(xIdx .* scoresInComp) / wsum);
                    odCy = round(sum(yIdx .* scoresInComp) / wsum);
                else
                    odCx = round(mean(xIdx));
                    odCy = round(mean(yIdx));
                end
            end
        end
    else
        % Fallback: no bright components found, take global argmax of scoreMap.
        [~, idx]      = max(scoreMap(:));
        [odCy, odCx]  = ind2sub(size(scoreMap), idx);
    end

    %% 12. Debug info (kept compatible with denemeMain.m and visualizers)
    debugInfo.fieldMask           = fieldMask;
    debugInfo.brightMap           = brightMap;
    debugInfo.brightScore         = brightStrong;
    debugInfo.vesselResponse      = vesselResponse;
    debugInfo.vesselMap           = vesselMap;
    debugInfo.vesselDensity       = vesselDensity;
    debugInfo.vesselAccumulation  = vesselDensity;
    debugInfo.clusteredVessels    = vesselDensity;
    debugInfo.sidePrior           = ones(H, W);
    debugInfo.horizontalBandPrior = horizontalBandPrior;
    debugInfo.lesionPenalty       = lesionPenalty;
    debugInfo.scoreMap            = scoreMap;
    debugInfo.vesselEntropy       = zeros(H, W);
    debugInfo.brightCandidates    = brightCandidates;
    debugInfo.exudateMask         = exudateMask;
    debugInfo.greenSharp          = greenSharp;

end
