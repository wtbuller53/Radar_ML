%%
%{
This script has two dependencies:

The npy-matlab, https://github.com/kwikteam/npy-matlab

The existence of a folder named './tempDatabase/' with subfolders 
barker/  cw/  fmcw/  fsk/  hyp/  nlfm/  quad/

%}

%%  Establish where to get the input data
radarml_home = '/ws1/itar/WaveGen/RadarML/';
% The files of data collected by ARESTOR 
arestor_file = dir([radarml_home,'/UCLRESM/*.npy']);

% Spectrogram dynamic range, fft length and overlap
dynamicRange_dB = 30;
fft_length = 60;
fft_overlap = 30;

%{ 
Image size - this is set to 227x227 for the pre-trained SqueezeNet
architecture. If using other architectures, then these may need to be
adjusted.
%}
pixels_x = 227;
pixels_y = 227;

% frequency shift and additive noise parameters
numberOfShifts = 7; % number of arbitrary frequency shift realizations
numberOfNoiseLevels = 4; % number of arbitrary additive noise realizations
min_SNR = 10;  % linear value (not deciBels) where SNR is var(sig)/var(noise)

for n = 1:length(arestor_file)
    data = readNPY([arestor_file(n).folder, '/',...
        arestor_file(n).name]);
    % Currently only using the first sample from the first ADC without
    % modification, or additive noise
    iq = squeeze(radar_ml_iq(data(1,1,:)));
    % Clip the data to where the signal is and form a smoothed spectrogram
    H1 = max(abs(iq))/2;
    s0 = find(abs(iq)>H1,1,'first');
    s1 = find(abs(iq)>H1,1,'last');
    sig0 = iq(s0:s1);

    %% Loop with frequency shifts
    frequencyShifts = [0;rand(numberOfShifts,1)];
    additiveNoise = [0;rand(numberOfNoiseLevels,1)];
    
    for shif = 1:numberOfShifts
        shiftIndex = round(frequencyShifts(shif)*(length(sig0)-2));
        Sp0 = fft(sig0);
        sig_shift = ifft([Sp0(shiftIndex+1:end);Sp0(1:shiftIndex)]);
        for nois = 1:numberOfNoiseLevels
            signal_amplitude = std(sig0);
            noise_level = additiveNoise(nois)*signal_amplitude/sqrt(min_SNR);
            sig = sig_shift + ( sqrt(2)^(-1)*noise_level*...
                (randn(length(sig0),1)+1i*randn(length(sig0),1)) );

            sfsig = spectrogram(sig,fft_length,fft_overlap);
            imsf = smoothdata2(db(sfsig),"movmedian");
            imagesc(imsf);
            axis xy; axis square; axis off;
            Pmax = max(imsf(:));
            clim = ([Pmax-dynamicRange_dB, Pmax]);
            % format the image for export and close figure
            fig = gcf();
            fig.Position(3:4) = [pixels_x pixels_y];
            namod = modname(arestor_file(n).name);
            nufil = ['./tempDatabase/',namod,'/', arestor_file(n).name];
            nufil(end-3:end) = [];
            nufil = [nufil, '_shift_', num2str(shiftIndex),'_of_', ...
                num2str(length(sig)), '_snr_', ...
                num2str(round(db(signal_amplitude/max(noise_level,1e-4)))), '.png' ];
            exportgraphics(fig,nufil,Units="pixels",Width=pixels_x,Height=pixels_y);
            close(gcf);
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
