start([colorVid]);

trigger(colorVid);
[colorIm, colorTime, colorMeta] = getdata(colorVid);

stop([colorVid]);

%flip image
colorIm = fliplr(colorIm);
colorIm = imcrop(colorIm, [400 500 900 300]);
colorIm = imgaussfilt(colorIm,0.2);

%show orignal image
%figure(2)
%image(colorIm)


I = rgb2gray(colorIm);
[~, threshold] = edge(I,'Canny');
BW = edge(I, 'Canny',threshold*0.8);

figure(1)
imshow(BW)
%grid on;
hold on;

[centers, radii, metric] = imfindcircles(BW,[3 15]);
% %centersStrong5 = centers(1:5);
% %radiiStrong5 = radii(1:5);
% %metricStrong5 = metric(1:5);
viscircles(centers, radii,'EdgeColor','b');

[h,theta, rho] =hough(BW);
% imshow(imadjust(mat2gray(h)), [], 'XData', theta, 'YData', rho, 'InitialMagnification','fit');
% axis on
% axis normal
% hold on
% colormap(hot);
% 
P = houghpeaks(h,1000,'threshold',ceil(0.005*max(h(:))));
% 
lines = houghlines(BW, theta, rho, P, 'FillGap', 4, 'MinLength', 8);

% figure(1)
% imshow(BW)
% hold on;
%0,0 is top left
%plot([250,250],[150,250], 'LineWidth', 5, 'Color', 'blue');
max_len = 0;
points = zeros(8,length(lines));
for k = 1:length(lines)
    xy = [lines(k).point1; lines(k).point2];
    gradient = rad2deg(atan2((xy(3)-xy(4)),abs(xy(2)-xy(1)))); %gradient always between +-90 as abs(y1-y2)
        
    points(:,k) = [xy(1),xy(3),xy(2),xy(4),gradient,0,0,0];
    c = 'green';
    if (abs(gradient) < 1)
        c = 'yellow';
    end
    if (abs(gradient) > 85)
        c = 'red';
    end
    plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', c);
end

radiusThresh = 35; %pixels
gradientThresh = 10; %degrees
for i = 1:length(points)
    currentLine = points(:,i);
    currentCP = [(currentLine(1)+currentLine(3))/2, (currentLine(2)+currentLine(4))/2];
    currentGrad = currentLine(5);
    closeLineCount = 0;
    closeCircleCount = 0;
    
    for j = 1:length(points)
        if(j~=i)
            testLine = points(:,j);
            testGrad = testLine(5);
            testLength = sqrt((testLine(1)-testLine(3))^2 + (testLine(2)-testLine(4))^2);
            testCP = [(testLine(1)+testLine(3))/2, (testLine(2)+testLine(4))/2];
            
            anglebetween = abs(testGrad - currentGrad);
            parCheckLow = anglebetween < gradientThresh/2; %parallel check 1
            parCheckHigh = anglebetween > 180 - gradientThresh/2; %parallel check 2
            perCheckLow = anglebetween < 90 + gradientThresh/2; %perpendicular check 1
            perCheckHigh = anglebetween > 90 - gradientThresh/2; %perpendicular check 2
            
            if(parCheckLow || parCheckHigh)
                distance = sqrt((testCP(1)-currentCP(1))^2 + (testCP(2)-currentCP(2))^2);
                if(distance <= radiusThresh)
                    closeLineCount = closeLineCount+1;
                end
            end
            
            if(perCheckLow && perCheckHigh)
                distance = sqrt((testCP(1)-currentCP(1))^2 + (testCP(2)-currentCP(2))^2);
                if(distance <= radiusThresh)
                    closeLineCount = closeLineCount+testLength*1;
                end
            end
        end
    end
    
    for j = 1:length(centers)
        distance = sqrt((centers(j,1)-currentCP(1))^2 + (centers(j,2)-currentCP(2))^2);
        if(distance <= radiusThresh)
            closeCircleCount = closeCircleCount+1;
        end
    end
    
    points(6,i) = closeLineCount;
    points(7,i) = closeCircleCount;
    points(8,i) = 4*closeLineCount+1*closeCircleCount;
end

[Y,I]=sort(points(6,:),'descend');
[Y2,I2]=sort(points(7,:),'descend');
[Y3,I3]=sort(points(8,:),'descend');

topx = ceil(0.5*length(I3));
radi = true(topx,1)*radiusThresh;

% strongCloseLine = points(:,I(1:topx));
% strongCloseCircle = points(:,I2(1:topx));
% lineCP = transpose([(strongCloseLine(1,:)+strongCloseLine(3,:))/2; (strongCloseLine(2,:)+strongCloseLine(4,:))/2]);
% circleCP = transpose([(strongCloseCircle(1,:)+strongCloseCircle(3,:))/2; (strongCloseCircle(2,:)+strongCloseCircle(4,:))/2]);
% viscircles(lineCP, radi,'EdgeColor','r');
% viscircles(circleCP, radi,'EdgeColor','g');

StrongWeighted = points(:,I2(1:topx));
TopCPs = transpose([(StrongWeighted(1,:)+StrongWeighted(3,:))/2; (StrongWeighted(2,:)+StrongWeighted(4,:))/2]);
%viscircles(TopCPs, radi,'EdgeColor','g');

SetMidPoints = [TopCPs(1,:),1];
radiusThresh = 50;
%OutOfRange = 1;


for i = 2:length(TopCPs)
    nextPoint = TopCPs(i,:);
    %nextPointMatr =  ones(size(SetMidPoints,1),2)*nextPoint;
    Distances = hypot(SetMidPoints(:,1) - nextPoint(1),SetMidPoints(:,2) - nextPoint(2));
    
    [d,I] = min(Distances);
    
    if (d <= radiusThresh)
        SetPop = SetMidPoints(I,3);
        AvgSum = SetMidPoints(I,1:2)*SetPop;
        AvgSum = AvgSum + nextPoint;
        Avg = AvgSum / (SetPop+1);
        
        SetMidPoints(I,:) = [Avg, SetPop+1];
    else
        SetMidPoints(size(SetMidPoints,1)+1,:) = [nextPoint, 1];
    end         
end

radi = true(size(SetMidPoints,1),1)*radiusThresh;
viscircles(SetMidPoints(:,1:2), radi,'EdgeColor','r');

width = 100;
height = 100;
%croppedImages = zeros(size(SetMidPoints,1),width,height,3);
clear croppedImages;
for i = 1:size(SetMidPoints,1)
    x = ceil(SetMidPoints(i,1)-(width/2));
    y = ceil(SetMidPoints(i,2)-(height/2));
    croppedImages{i} = imcrop(colorIm, [x y width height]);
end


    
    
    
    