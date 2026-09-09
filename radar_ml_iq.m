%% function iq = radar_ml_iq(data)
%{
% Summary: return complex iq samples from Radar_ML ADC sampled data
% 
% input: tensor NxMxK interleaved inphase and quadrature data from 
%         where N = 3, number of ADC recorders
%               M = 8000, number of waveform transmissions recorded
%               K = 33600, alternating iq-samples at ADC at 120 MHz;
% output: tensor NxMxL iq data, where L = K/2 
%
%}

function iq = radar_ml_iq(data)

% The integers from the ADC are integers, scaled to Voltage
% Inphase and Quadrature values are interlaced
inphase = double(data(:,:,1:2:end-1));
quadrature = double(data(:,:,2:2:end));
iq = inphase + (1j*quadrature);


