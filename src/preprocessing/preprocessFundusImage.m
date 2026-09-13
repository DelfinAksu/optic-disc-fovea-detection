function preprocessed = preprocessFundusImage(img)

    targetSize = [512 512];

    if size(img,3) == 1
        img = repmat(img, [1 1 3]);
    end

    img = imresize(img, targetSize);

    % Convert to double
    img = im2double(img);

    % Extract channels
    red = img(:,:,1);
    green = img(:,:,2);

    % CLAHE (contrast enhancement)
    red = adapthisteq(red);
    green = adapthisteq(green);

    % Smoothing
    red = imgaussfilt(red, 6);
    green = imgaussfilt(green, 6);

    preprocessed.red = red;
    preprocessed.green = green;
    preprocessed.originalSize = size(img);

end