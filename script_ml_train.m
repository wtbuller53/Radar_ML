%% Script to train and evaluate classifier using image datastore

% identify the location of the datastore
waveform_imds = imageDatastore('./tempDatabase/', ...
    'IncludeSubfolders',true, ...
    'LabelSource','foldernames');

% split the data store for training, testing, and validation
[imdsTrain,imdsTest,imdsValidation] = splitEachLabel(waveform_imds,0.8,0.1);

% This is the number of modulation types
numClasses = 7;

% This example, based on the Radar and Communications Waveform Classification 
% Using Deep Learning from MATLAB, uses squeezenet
net = imagePretrainedNetwork("squeezenet","NumClasses",numClasses,"ClassNamesType","string");

newDropoutLayer = dropoutLayer(0.6,'Name','new_dropout');
net = replaceLayer(net,'drop9',newDropoutLayer);

net = setLearnRateFactor(net,"conv10/Weights",20);
net = setLearnRateFactor(net,"conv10/Bias",20);

options = trainingOptions('sgdm', ...
    'MiniBatchSize',128, ...
    'MaxEpochs',5, ...
    'InitialLearnRate',1e-3, ...
    'Shuffle','every-epoch', ...
    'Verbose',false, ...
    'Plots','training-progress',...
    'ValidationData',imdsValidation,...
    'Metrics','accuracy');

%% Training step
trainedNet = trainnet(imdsTrain,net,'crossentropy',options);

%% Testing
scores = minibatchpredict(trainedNet,imdsTest);
predicted = scores2label(scores,categories(imdsTest.Labels));

%% Present confusion (or Confidence) matrix
figure
confusionchart(imdsTest.Labels,predicted,'Normalization','column-normalized')
titlestring = { ['Training set size: ', num2str(size(imdsTrain.Files))]; ...
    ['Test set size: ', num2str(size(imdsTest.Files))]; ...
    ['Number of waveform classes: ', num2str(numClasses) ] };
title(titlestring);