%%
%{
This script has two dependencies:

The npy-matlab, https://github.com/kwikteam/npy-matlab

The existence of a folder named './tempDatabase/' with subfolders 
barker/  cw/  fmcw/  fsk/  hyp/  nlfm/  quad/

%}

%%  Establish where to get the input data
%% Script to create datastore from RadarML collected waveforms

radarml_home = '/ws1/itar/WaveGen/RadarML/';
% The files of data collected by ARESTOR
arestor_file = dir([radarml_home,'/UCLRESM/*.npy']);

% Spectrogram dynamic range, fft length and overlap
dynamicRange_dB = 30;
fft_length = 128;
fft_overlap = 64;

%{
Image size - this is set to 227x227 for the pre-trained SqueezeNet
architecture. If using other architectures, then these may need to be
adjusted.
%}
pixels_x = 227;
pixels_y = 227;

%% This is if imwrite() is being used
%imsf = uint8(zeros(pixels_y,pixels_x,3));

% frequency shift and additive noise parameters
numberOfShifts = 7; % number of arbitrary frequency shift realizations
numberOfNoiseLevels = 4; % number of arbitrary additive noise realizations
min_SNR = 10;  % linear value (not deciBels) where SNR is var(sig)/var(noise)

for n = 1:length(arestor_file)
    data = readNPY([arestor_file(n).folder, '/',...
        arestor_file(n).name]);

    % Currently only using the first sample from the first ADC without
    % modification, or additive noise
    % TODO: Use more of the collected signals
    iq = squeeze(radar_ml_iq(data(1,1,:)));

    %% add noise to signal prior to detection
    additiveNoise = [0;rand(numberOfNoiseLevels,1)];
    for nois = 1:numberOfNoiseLevels
        signal_amplitude = max(abs(iq));
        additional_noise_level = additiveNoise(nois)*signal_amplitude/sqrt(min_SNR);
        sig = iq + ( sqrt(2)^(-1)*additional_noise_level*...
            (randn(length(iq),1)+1i*randn(length(iq),1)) );

        %% Loop with frequency shifts
        frequencyShifts = [0;rand(numberOfShifts,1)];

        for shif = 1:numberOfShifts
            shiftIndex = round(frequencyShifts(shif)*(length(sig)-2));
            Sp0 = fft(sig);
            sig_shift = ifft([Sp0(shiftIndex+1:end);Sp0(1:shiftIndex)]);
            % Clip the data to where the signal is and form a smoothed spectrogram
            H1 = max(abs(sig_shift))/2;
            s0 = find(abs(sig_shift)>H1,1,'first');
            s1 = find(abs(sig_shift)>H1,1,'last');
            sig0 = sig_shift(s0:s1);
            
            % TODO: Estimate PDW features here
            % pdws = iq2pdws(sig_shift,H1);

            sfsig = db(spectrogram(sig0,fft_length,fft_overlap));
            [imrow, imcol] = size(sfsig);
            
            % This is how one could implement using imwrite()
            % This would be faster and more appropriate for single channel
            % output.
            %{
            F = griddedInterpolant({1:imrow,1:imcol},sfsig);
            F.Method = "spline";
            % crop the noise floor at the dynamic range
            sfsig = sfsig - max(sfsig(:)) + dynamicRange_dB;
            sfsig(sfsig<0) = 0;
            % scale the channels to [0,1] for imwrite
            sfsig = sfsig / max(sfsig(:));         
            imsf(:,:,1) = uint8(F({linspace(1,imrow,pixels_x),linspace(1,imcol,pixels_y)}));
            imsf(:,:,2) = imsf(:,:,1);
            imsf(:,:,3) = imsf(:,:,1);
            % Then one would use imwrite(imsf) to 'nufil' as below
            %}

            fig2exp = figure();
            imagesc(sfsig); colormap(fig2exp,gray);
            axis square; axis xy; axis off;

            namod = modname(arestor_file(n).name);
            nufil = ['./tempDatabase/',namod,'/', arestor_file(n).name];
            nufil(end-3:end) = [];
            nufil = [nufil, '_shift_', num2str(shiftIndex),'_of_', ...
                num2str(length(sig)), '_snr_', ...
                num2str(round(db(signal_amplitude/max(additional_noise_level,1e-4)))), '.png' ];
            exportgraphics(fig2exp,nufil,Units="pixels",Width=227,Height=227);
            close(fig2exp);
        end
    end
end

%% function y = modname(x)
%{
% Simple function to return the modulation category based on the filename
%}
function y = modname(x)

modtyp = {'_fmcw', '_hyp', '_nlfm', '_quad', '_barker','_fsk', '_cw'};
y = [];
m = 0;

while isempty(y)
    m = m+1;
    a = regexp(x,modtyp{m},'once');
    if ~isempty(a)
        y = modtyp{m}(2:end);
    end
end
end
