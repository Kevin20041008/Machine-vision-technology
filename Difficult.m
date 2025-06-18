%拼接Difficult全景图片的类
classdef Difficult
    methods (Static)
        function globalImage = stitchDifficultImages(imageFolderPath)

            % 获取文件夹中所有D开头的图像文件（所有图片均为D1，D2...D8）
            imageFiles = dir(fullfile(imageFolderPath, 'D*.jpg'));
            if isempty(imageFiles)
                imageFiles = dir(fullfile(imageFolderPath, 'D*.png'));
            end
            
            % 按文件名排序
            [~, idx] = sort({imageFiles.name});
            imageFiles = imageFiles(idx);
            numImages = length(imageFiles);
            
            if numImages < 2
                error('至少需要两张图像进行拼接');
            end

            %读取所有图像
            images = cell(numImages, 1);
            for i = 1:numImages
                fullImagePath = fullfile(imageFolderPath, imageFiles(i).name);
                images{i} = imread(fullImagePath);
                fprintf('  已读取图像: %s\n', imageFiles(i).name);
                
                % 转换为灰度图像用于特征匹配
                if size(images{i}, 3) == 3
                    grayImages{i} = rgb2gray(images{i});
                else
                    grayImages{i} = images{i};
                end
            end

            % 初始化变换矩阵，以第一张图片作为参考
            H = cell(numImages, 1);
            H{1} = eye(3); 

            % 逐对拼接图像
            fprintf('开始逐对拼接图像...\n');
            for i = 2:numImages
                fprintf('  正在拼接图像 %s 和图像 %s...\n', imageFiles(i-1).name, imageFiles(i).name);
                
                % 检测特征点
                points1 = detectSURFFeatures(grayImages{i-1});
                points2 = detectSURFFeatures(grayImages{i});
                
                % 提取特征描述符
                [features1, validPoints1] = extractFeatures(grayImages{i-1}, points1);
                [features2, validPoints2] = extractFeatures(grayImages{i}, points2);
                
                % 匹配特征
                indexPairs = matchFeatures(features1, features2, 'MaxRatio', 0.8, 'Unique', true);
                
                matchedPoints1 = validPoints1(indexPairs(:,1), :);
                matchedPoints2 = validPoints2(indexPairs(:,2), :);
                
                fprintf('    匹配到 %d 对特征点\n', size(matchedPoints1, 1));
                
                if size(matchedPoints1, 1) < 4
                    warning('匹配点对不足，尝试使用前一图像的变换矩阵');
                    H{i} = H{i-1};
                    continue;
                end
                
                % 估计变换矩阵
                try
                    [tform, inlierIdx] = estimateGeometricTransform2D(...
                        matchedPoints2, matchedPoints1, 'projective', ...
                        'MaxNumTrials', 2000, 'Confidence', 99.9, 'MaxDistance', 5);
                    
                    fprintf('    RANSAC找到 %d 个内点\n', sum(inlierIdx));
                    
                    % 累积变换
                    H{i} = H{i-1} * tform.T;
            end

            % 计算全局图像尺寸
            [xLimits, yLimits] = Difficult.calculateGlobalBounds(images, H);
            
            % 创建全局图像
            xOffset = round(abs(xLimits(1)));
            yOffset = round(abs(yLimits(1)));
            globalWidth = round(xLimits(2) - xLimits(1));
            globalHeight = round(yLimits(2) - yLimits(1));
            
            % 创建全景图
            % 修改后的图像融合部分
            globalImage = zeros([globalHeight, globalWidth, 3], 'double'); % 改为double类型以支持累加
            weightMap = zeros([globalHeight, globalWidth], 'double');
            
            % 变换每张图像并融合
            for i = 1:numImages
                fprintf('  正在将图像 %s 融合到全局图像...\n', imageFiles(i).name);
                
                % 创建变换对象并调整偏移
                tform = projective2d(H{i});
                tform.T(3,1) = tform.T(3,1) + xOffset;
                tform.T(3,2) = tform.T(3,2) + yOffset;
                
                % 变换图像
                warpedImage = imwarp(images{i}, tform, 'OutputView', imref2d([globalHeight, globalWidth]));
                
                % 创建掩码
                mask = imwarp(true(size(images{i},1), size(images{i},2)), tform, ...
                          'OutputView', imref2d([globalHeight, globalWidth]));
                
                % 确保warpedImage是double类型
                warpedImage = im2double(warpedImage);

                % 对每个颜色通道分别处理
                for c = 1:3
                    globalImage(:,:,c) = globalImage(:,:,c) + warpedImage(:,:,c) .* double(mask);
                end
                weightMap = weightMap + double(mask);
            end
            
            % 归一化处理
            weightMap(weightMap == 0) = 1; % 避免除以零
            globalImage = globalImage ./ weightMap;
            globalImage = im2uint8(globalImage); % 转换回uint8
            
            fprintf('图像拼接完成\n');
            figure, imshow(globalImage);
            title('Difficult类全景图');
        end
        
        function [xLimits, yLimits] = calculateGlobalBounds(images, H)
            % 计算所有图像变换后的边界
            numImages = numel(images);
            allX = [];
            allY = [];
            
            for i = 1:numImages
                [h, w, ~] = size(images{i});
                
                % 图像四个角点
                corners = [1 1; w 1; w h; 1 h];
                
                % 变换到全局坐标系
                cornersTrans = transformPointsForward(projective2d(H{i}), corners);
                
                allX = [allX; cornersTrans(:,1)]; %#ok<AGROW>
                allY = [allY; cornersTrans(:,2)]; %#ok<AGROW>
            end
            
            % 添加10%的边界缓冲
            xRange = max(allX) - min(allX);
            yRange = max(allY) - min(allY);
            xLimits = [min(allX)-0.1*xRange, max(allX)+0.1*xRange];
            yLimits = [min(allY)-0.1*yRange, max(allY)+0.1*yRange];
        end
    end
end