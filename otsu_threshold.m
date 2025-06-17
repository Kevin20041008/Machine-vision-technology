
function OtsuImg = otsu_threshold()
    % 实验：OTSU阈值检测
    img = imread('testing.jpg');
    if size(img, 3) == 3
        gray = rgb2gray(img);
    else
        gray = img;
    end

    % 使用 OTSU 方法计算阈值
    level = graythresh(gray);  % 返回归一化阈值（0~1）
    T = level * 255;

    % 应用阈值进行二值化
    OtsuImg = uint8(zeros(size(gray)));
    OtsuImg(gray >= T) = 255;

    % 显示图像
    figure;
    subplot(1, 3, 1), imshow(img), title('原图');
    subplot(1, 3, 2), imshow(gray), title('灰度图');
    subplot(1, 3, 3), imshow(OtsuImg), title(['OTSU 阈值图像 T = ', num2str(T, '%.2f')]);
end
