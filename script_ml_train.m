%% Script to train and evaluate classifier using image datastore

inputSize = [227,227,1];
% identify the location of the datastore
waveform_imds = imageDatastore('./tempDatabase/', ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames');

% split the data store for training, testing, and validation
[imdsTrain,imdsTest,imdsValidation] = splitEachLabel(waveform_imds,0.8,0.1);

imageAugmenter = imageDataAugmenter( ...
    RandXReflection=true);

augimdsTrain = augmentedImageDatastore(inputSize(1:2),imdsTrain, ...
    ColorPreprocessing="gray2rgb",DataAugmentation=imageAugmenter);
augimdsTest = augmentedImageDatastore(inputSize(1:2),imdsTest, ...
    ColorPreprocessing="gray2rgb");
augimdsValidation = augmentedImageDatastore(inputSize(1:2),imdsValidation, ...
    ColorPreprocessing="gray2rgb");

% This is the number of modulation types
numClasses = 7;

% This example, based on the Radar and Communications Waveform Classification 
% Using Deep Learning from MATLAB, uses squeezenet
net = imagePretrainedNetwork("squeezenet","NumClasses",numClasses,"ClassNamesType","string");
newDropoutLayer = dropoutLayer(0.6,'Name','new_dropout');
net = replaceLayer(net,'drop9',newDropoutLayer);
net = setLearnRateFactor(net,"conv10/Weights",20);
net = setLearnRateFactor(net,"conv10/Bias",20);

options = trainingOptions('adam', ...
    'MiniBatchSize',32, ...
    'MaxEpochs',10, ...
    'InitialLearnRate',1e-4, ...
    'Shuffle','every-epoch', ...
    'Verbose',false, ...
    'Plots','training-progress',...
    'ValidationData',augimdsValidation,...
    'Metrics','accuracy');

%% Training step
trainedNet = trainnet(augimdsTrain,net,'crossentropy',options);
netfile = strcat("squeeze_",string(date));
save(netfile,"trainedNet");

%% Testing
scores = minibatchpredict(trainedNet,augimdsTest);
predicted = scores2label(scores,categories(imdsTest.Labels));

%% Present confusion (or Confidence) matrix
figure
cmatrix = confusionchart(imdsTest.Labels,predicted,'Normalization','column-normalized');
titlestring = { ['Training set size: ', num2str(length(augimdsTrain.Files))]; ...
    ['Test set size: ', num2str(length(imdsTest.Files))]; ...
    ['Number of waveform classes: ', num2str(numClasses) ] };
title(titlestring);