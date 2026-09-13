function fig = visualizeODDetection(img, pre, debugInfo, odCx, odCy, gtCx, gtCy, titleStr)
    if nargin < 8 || isempty(titleStr); titleStr = ''; end

    img512 = imresize(img, [512 512]);

    fig = figure('Visible', 'off', 'Position', [50 50 1500 1900], 'Color', 'w');

    % ============ Row 1 — Inputs ============
    subplot(4,3,1);
    imshow(img512); hold on;
    plot(odCx, odCy, 'r+', 'MarkerSize', 18, 'LineWidth', 2.5);
    if ~isempty(gtCx)
        plot(gtCx, gtCy, 'go', 'MarkerSize', 14, 'LineWidth', 2.5);
        legend('Predicted','GT','Location','northeast','TextColor','w','Color','k');
    end
    title('1) Orijinal + Pred(+) / GT(o)');

    subplot(4,3,2);
    imshow(pre.red, []);
    title('2) Preprocessed Red');

    subplot(4,3,3);
    imshow(debugInfo.greenSharp, []);
    title('3) Green Sharp (unsharp mask)');

    % ============ Row 2 — Brightness pipeline ============
    subplot(4,3,4);
    imshow(debugInfo.fieldMask);
    title('4) Field Mask');

    subplot(4,3,5);
    imshow(debugInfo.brightMap, []);
    colormap(gca, 'hot');
    title('5) Brightness Map (sigma=16)');

    subplot(4,3,6);
    imshow(debugInfo.brightCandidates); hold on;
    plot(odCx, odCy, 'r+', 'MarkerSize', 16, 'LineWidth', 2);
    if ~isempty(gtCx)
        plot(gtCx, gtCy, 'go', 'MarkerSize', 12, 'LineWidth', 2);
    end
    title('6) Bright Candidates (top 5%)');

    % ============ Row 3 — Vessel pipeline ============
    subplot(4,3,7);
    imshow(debugInfo.vesselResponse, []);
    title('7) Vessel Response (multi-bothat)');

    subplot(4,3,8);
    imshow(debugInfo.vesselMap);
    title('8) Vessel Map (binary)');

    subplot(4,3,9);
    imshow(debugInfo.vesselDensity, []);
    colormap(gca, 'hot');
    title('9) Vessel Density (disk r=40)');

    % ============ Row 4 — Penalties and final ============
    subplot(4,3,10);
    imshow(debugInfo.exudateMask);
    title('10) Exudate Mask');

    subplot(4,3,11);
    imshow(debugInfo.lesionPenalty, []);
    colormap(gca, 'hot');
    title('11) Lesion Penalty');

    subplot(4,3,12);
    imshow(debugInfo.scoreMap, []);
    colormap(gca, 'hot');
    hold on;
    plot(odCx, odCy, 'g+', 'MarkerSize', 22, 'LineWidth', 3);
    if ~isempty(gtCx)
        plot(gtCx, gtCy, 'co', 'MarkerSize', 16, 'LineWidth', 2.5);
    end
    title('12) Score Map + Pred(+) / GT(o)');

    if ~isempty(titleStr)
        sgtitle(titleStr, 'FontSize', 14, 'FontWeight', 'bold');
    end

end
