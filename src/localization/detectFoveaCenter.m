function [foveaCx, foveaCy, debugInfo] = detectFoveaCenter(pre, odCx, odCy)

    red    = pre.red;
    [H, W] = size(red);

    %% 1. Anatomical expected fovea location
    FOVEA_DX_PX = 152;
    FOVEA_DY_PX = 25;

    if odCx < W / 2
        % OD on left half of image -> fovea is to the RIGHT of OD
        expectedX = odCx + FOVEA_DX_PX;
    else
        % OD on right half -> fovea is to the LEFT of OD
        expectedX = odCx - FOVEA_DX_PX;
    end
    expectedY = odCy + FOVEA_DY_PX;

    %% 2. Tight rectangular search window around expected location
    boxR    = 70;
    sideMin = max(1, round(expectedX - boxR));
    sideMax = min(W, round(expectedX + boxR));
    yMin    = max(1, round(expectedY - boxR));
    yMax    = min(H, round(expectedY + boxR));

    %% 3. Field mask + heavy erosion (avoid vignette / edge pixels)
    fieldMask = red > 0.05;
    fieldMask = imfill(fieldMask, 'holes');
    fieldMask = bwareaopen(fieldMask, 5000);
    fieldErod = imerode(fieldMask, strel('square', 35));

    %% 4. Darkness map (red channel inverse, smoothed at fovea scale)
    darkMap = mat2gray(imgaussfilt(1 - red, 8));

    %% 5. Tight distance prior centered at expected fovea location
    [X, Y]        = meshgrid(1:W, 1:H);
    distExp       = sqrt((X - expectedX).^2 + (Y - expectedY).^2);
    distancePrior = mat2gray(exp(-(distExp.^2) / (2 * 40^2)));

    %% 6. Combined fovea score
    foveaScore = 0.45 * darkMap + 0.55 * distancePrior;
    foveaScore = max(foveaScore, 0);

    %% 7. Restrict to search window AND eroded field
    searchMask = false(H, W);
    searchMask(yMin:yMax, sideMin:sideMax) = true;
    searchMask = searchMask & fieldErod;
    foveaScore(~searchMask) = 0;

    %% 8. Argmax (or anatomical fallback if score is empty)
    if max(foveaScore(:)) < 1e-9
        foveaCx = round(expectedX);
        foveaCy = round(expectedY);
    else
        [~, idx]            = max(foveaScore(:));
        [foveaCy, foveaCx]  = ind2sub([H, W], idx);
    end

    %% Debug info for visualization
    debugInfo.expectedX     = expectedX;
    debugInfo.expectedY     = expectedY;
    debugInfo.searchMask    = searchMask;
    debugInfo.fieldErod     = fieldErod;
    debugInfo.darkMap       = darkMap;
    debugInfo.distancePrior = distancePrior;
    debugInfo.foveaScore    = foveaScore;

end
