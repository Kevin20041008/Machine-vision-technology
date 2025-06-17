
function ThresholdImg = iterative_threshold()
    % 实验：迭代的最优阈值选择
    img = imread('testing.jpg');
    if size(img, 3) == 3
        gray = rgb2gray(img);
    else
        gray = img;
    end

    T = mean(gray(:));
    delta_T = 1;

    while delta_T > 0.5
        G1 = gray(gray >= T);
        G2 = gray(gray < T);
        mean1 = mean(G1(:));
        mean2 = mean(G2(:));
        T_new = (mean1 + mean2) / 2;
        delta_T = abs(T - T_new);
        T = T_new;
    end

    ThresholdImg = uint8(zeros(size(gray)));
    ThresholdImg(gray >= T) = 255;

    figure;
    subplot(1, 3, 1), imshow(img), title('原图');
    subplot(1, 3, 2), imshow(gray), title('灰度图');
    subplot(1, 3, 3), imshow(ThresholdImg), title(['迭代阈值图像 T = ', num2str(T, '%.2f')]);
end
