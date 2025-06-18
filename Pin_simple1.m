%% 图片拼接的函数
function stitched_img = stitch_pair(img1, img2, direction)
    % 转换为灰度图像
    gray1 = rgb2gray(img1);
    gray2 = rgb2gray(img2);
    
    % 特征检测并提取
    points1 = detectSURFFeatures(gray1);
    points2 = detectSURFFeatures(gray2);
    [features1, valid_points1] = extractFeatures(gray1, points1);
    [features2, valid_points2] = extractFeatures(gray2, points2);
    
    % 特征匹配（增加匹配阈值）
    indexPairs = matchFeatures(features1, features2, 'MatchThreshold', 1.0, 'MaxRatio', 0.6);
    
    % 确保有足够匹配点
    if size(indexPairs, 1) < 4
        error('Not enough matching points found between images.');
    end
    
    matchedPoints1 = valid_points1(indexPairs(:,1), :);
    matchedPoints2 = valid_points2(indexPairs(:,2), :);
    
    % 根据方向确定参考图像
    if strcmp(direction, 'left')
        fixedPoints = matchedPoints2.Location;
        movingPoints = matchedPoints1.Location;
    else
        fixedPoints = matchedPoints1.Location;
        movingPoints = matchedPoints2.Location;
    end
    
    % 估计变换矩阵（使用RANSAC算法）
    tform = estimateGeometricTransform2D(movingPoints, fixedPoints, 'projective', ...
        'MaxNumTrials', 2000, 'Confidence', 99.9);
    
    % 计算输出图像大小
    [h1, w1, ~] = size(img1);
    [h2, w2, ~] = size(img2);
    
    % 变换图像角点
    if strcmp(direction, 'left')
        corners = [1 1; w1 1; 1 h1; w1 h1];
        transformedCorners = transformPointsForward(tform, corners);
        xlim = [min(1, min(transformedCorners(:,1))) max(w2, max(transformedCorners(:,1)))];
        ylim = [min(1, min(transformedCorners(:,2))) max(h2, max(transformedCorners(:,2)))];
    else
        corners = [1 1; w2 1; 1 h2; w2 h2];
        transformedCorners = transformPointsForward(tform, corners);
        xlim = [min(1, min(transformedCorners(:,1))) max(w1, max(transformedCorners(:,1)))];
        ylim = [min(1, min(transformedCorners(:,2))) max(h1, max(transformedCorners(:,2)))];
    end
    
    % 创建输出视图
    outputView = imref2d([round(diff(ylim))+1, round(diff(xlim))+1], xlim, ylim);
    
    % 图像变换
    if strcmp(direction, 'left')
        warpedImg1 = imwarp(img1, tform, 'OutputView', outputView);
        warpedImg2 = imwarp(img2, affine2d(eye(3)), 'OutputView', outputView);
    else
        warpedImg1 = imwarp(img1, affine2d(eye(3)), 'OutputView', outputView);
        warpedImg2 = imwarp(img2, tform, 'OutputView', outputView);
    end
    
    % 图像融合（改进的加权平均方法）
    stitched_img = blend_images(warpedImg1, warpedImg2);
end

%% 图像融合的函数
function blended = blend_images(img1, img2)
    % 创建掩模
    mask1 = any(img1 > 0, 3);
    mask2 = any(img2 > 0, 3);
    overlap = mask1 & mask2;
    
    % 初始化混合图像
    blended = zeros(size(img1), 'like', img1);
    
    % 非重叠区域直接复制
    blended = blended + img1 .* uint8(mask1 & ~overlap);
    blended = blended + img2 .* uint8(mask2 & ~overlap);
    
    % 重叠区域加权融合
    [rows, cols, ~] = size(img1);
    for i = 1:rows
        for j = 1:cols
            if overlap(i,j)
                % 计算权重
                if mask1(i,j) && mask2(i,j)
                    % 找到重叠区域的左右边界
                    left = find(mask1(i,:) & mask2(i,:), 1, 'first');
                    right = find(mask1(i,:) & mask2(i,:), 1, 'last');
                    
                    % 线性渐变权重
                    alpha = (j - left) / (right - left);
                    blended(i,j,:) = (1-alpha)*double(img1(i,j,:)) + alpha*double(img2(i,j,:));
                elseif mask1(i,j)
                    blended(i,j,:) = img1(i,j,:);
                else
                    blended(i,j,:) = img2(i,j,:);
                end
            end
        end
    end
    
    blended = uint8(blended);
end

%% 主函数
%读取simple类的7张图像
image_files = {'S1.jpg', 'S2.jpg', 'S3.jpg', 'S4.jpg', 'S5.jpg', 'S6.jpg', 'S7.jpg'};
images = cell(1, 7);
for i = 1:7
    images{i} = imread(image_files{i});
end

% 初始化全景图，已知这类图片有7张，因此以第四张为基准
panorama = images{4};

% 向左拼接（从中间向左）
for i = 3:-1:1
    panorama = stitch_pair(images{i}, panorama, 'left');
end

% 向右拼接（从中间向右）
for i = 5:7
    panorama = stitch_pair(panorama, images{i}, 'right');
end

% 显示结果
figure;
imshow(panorama);
title('simple类全景图拼接结果');

% 保存结果
imwrite(panorama, 'panorama_result.jpg');