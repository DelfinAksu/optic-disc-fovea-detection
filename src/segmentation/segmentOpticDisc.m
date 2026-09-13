function [odMask, debugInfo] = segmentOpticDisc(pre, odCx, odCy, debugInfoOD)

    red    = pre.red;
    [H, W] = size(red);

    if nargin < 4 || ~isstruct(debugInfoOD) || ~isfield(debugInfoOD, 'vesselMap')
        vesselMap = false(H, W);
    else
        vesselMap = debugInfoOD.vesselMap;
    end

    %% 1. Define ROI around OD center
    roiR = 80;
    x1 = max(1, odCx - roiR); x2 = min(W, odCx + roiR);
    y1 = max(1, odCy - roiR); y2 = min(H, odCy + roiR);

    roiRed   = red(y1:y2, x1:x2);
    roiVMap  = vesselMap(y1:y2, x1:x2);

    %% 2. Inpaint vessels inside ROI
    
    roiVDilated = imdilate(roiVMap, strel('disk', 3));
    roiRed8     = im2uint8(roiRed);

    if any(roiVDilated(:))
        roiInpainted = inpaintExemplar( ...
            double(roiRed8) / 255.0, roiVDilated);
    else
        roiInpainted = double(roiRed8) / 255.0;
    end

    %% 3. Threshold: max( Otsu, 78th percentile )
    otsuT = graythresh(roiInpainted);
    pctT  = quantile(roiInpainted(:), 0.78);
    threshold = max(otsuT, pctT);

    odCandRoi = roiInpainted > threshold;

    %% 4. Morphological cleanup
    odCandRoi = imclose(odCandRoi, strel('disk', 7));
    odCandRoi = imfill(odCandRoi, 'holes');
    odCandRoi = imopen(odCandRoi, strel('disk', 4));

    %% 5. Pick connected component closest to OD center
    centerXroi = odCx - x1 + 1;
    centerYroi = odCy - y1 + 1;

    odMaskRoi = false(size(odCandRoi));
    cc = bwconncomp(odCandRoi);

    if cc.NumObjects > 0
        bestK    = 0;
        bestDist = Inf;

        for k = 1:cc.NumObjects
            [yIdx, xIdx] = ind2sub(size(odCandRoi), cc.PixelIdxList{k});
            cyC = mean(yIdx); cxC = mean(xIdx);
            d   = sqrt((cxC - centerXroi)^2 + (cyC - centerYroi)^2);
            if d < bestDist
                bestDist = d;
                bestK    = k;
            end
        end

        if bestK > 0
            odMaskRoi(cc.PixelIdxList{bestK}) = true;
        end
    end

    %% 6. Final smooth + hole fill
    odMaskRoi = imclose(odMaskRoi, strel('disk', 3));
    odMaskRoi = imfill(odMaskRoi, 'holes');

    odMask = false(H, W);
    odMask(y1:y2, x1:x2) = odMaskRoi;

    %% Debug info
    debugInfo.roi          = [x1 y1 x2 y2];
    debugInfo.roiRed       = roiRed;
    debugInfo.roiVMap      = roiVMap;
    debugInfo.roiInpainted = roiInpainted;
    debugInfo.threshold    = threshold;
    debugInfo.odCandRoi    = odCandRoi;
    debugInfo.odMaskRoi    = odMaskRoi;

end

function out = inpaintExemplar(I, mask)

    try
        out = inpaintCoherent(I, mask);
    catch
        % Fallback: replace masked pixels with morphological closing
        I8     = im2uint8(I);
        closed = imclose(I8, strel('disk', 5));
        out    = I;
        out(mask) = double(closed(mask)) / 255.0;
    end
end
