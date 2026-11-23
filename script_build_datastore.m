%%
%{
This script has two dependencies:
1. The npy-matlab, https://github.com/kwikteam/npy-matlab
2. The existence of a folder named './tempDatabase/' with subfolders 
barker/  cw/  fmcw/  fsk/  hyp/  nlfm/  quad/
%}

%%  Establish where to get the input data
%% Script to create datastore from RadarML collected waveforms

rng(1885);

% Detector threshold number of standard deviation
N_sigma = 6;

if ispc
    radarml_home = '\\nas1\data\itar\WaveGen\RadarML\';
    arestor_file = dir([radarml_home,'\UCLRESM\*.npy']);
else
    radarml_home = '/ws1/itar/WaveGen/RadarML/';
    arestor_file = dir([radarml_home,'/UCLRESM/*.npy']);
end

sampling_frequency = 1.2e8;
pdw_table = table();

% Spectrogram dynamic range, fft length and overlap
dynamicRange_dB = 60;
fft_length = 128;
fft_overlap = 64;
noise_samples = 200;

%{
Image size - this is set to 227x227 for the pre-trained SqueezeNet
architecture. If using other architectures, then these may need to be
adjusted.
%}
pixels_x = 227;
pixels_y = 227;
pixels_z = 1;

% frequency shift and additive noise parameters
numberOfShifts = 7; % number of arbitrary frequency shift realizations
numberOfNoiseLevels = 9; % number of arbitrary additive noise realizations
min_SNR = 10;  % linear value (not deciBels) where SNR is var(sig)/var(noise)
dbugNoise = [];

for n = 1:length(arestor_file)
    data = readNPY([arestor_file(n).folder, '/',...
        arestor_file(n).name]);

    % Currently only using the first sample from the first ADC without
    % modification, or additive noise
    % TODO: Use more of the collected signals
    iq = squeeze(radar_ml_iq(data(1,1,:)));
    noise = std(iq(1:noise_samples));
    dbugNoise = [dbugNoise,noise];

    for shif = 1:numberOfShifts
        %% Loop with frequency shifts
        sig_shift = shift_sigs_RadarML(iq,'simple', N_sigma*noise);

        %% add noise to signal
        for nois = 1:numberOfNoiseLevels
            signal_amplitude = max(abs(sig_shift));
            noiseLevel = rand(1)*signal_amplitude/min_SNR;
            additive_noise = noiseLevel * ...
                (randn(length(sig_shift),1)+1i*randn(length(sig_shift),1)) / sqrt(2);
            sig = sig_shift + additive_noise;
            bg_sample = abs(sig(1:noise_samples));
            threshold = mean(bg_sample) + N_sigma*std(bg_sample);

            % Create the PDWs and clip the detection in sig0
            [pdws,sig0] = iq2pdw(sig,threshold,sampling_frequency);
            % Generate the spectrogram for the clipped detection
            sfsig = spectrogram(sig0,fft_length,fft_overlap);

            namod = modname(arestor_file(n).name);
            if ispc
                nufil = ['.\tempDatabase\',namod,'\', arestor_file(n).name];
            else
                nufil = ['./tempDatabase/',namod,'/', arestor_file(n).name];
            end
            nufil(end-3:end) = [];
            nufil = [nufil, num2str(n,'%04d'), '_', num2str(shif,'%03d'), ...
                '_', num2str(nois,'%03d'), '.png' ];

            %% display and export the figure
            if pixels_z == 3
                fig2exp = figure();
                fig2exp.Position = [100, 100, 400, 400];
                imagesc(db(sfsig)); colormap(fig2exp,gray);
                ctop = clim;
                clim([ctop(2)-dynamicRange_dB,ctop(2)]);
                axis xy; axis off;
                exportgraphics(fig2exp,nufil,Units="pixels",Width=227,Height=227);
                close(fig2exp);
            elseif pixels_z == 1
                [imrow,imcol] = size(sfsig);
                % crop the noise floor at the dynamic range
                im_sfsig = db(sfsig) - max(db(sfsig(:))) + dynamicRange_dB;
                im_sfsig(im_sfsig<0) = 0;
                % scale the values between 0 and 1
                F = griddedInterpolant({1:imrow,1:imcol},im_sfsig/max(im_sfsig(:)));
                F.Method = "nearest";
                imsf = F({linspace(1,imrow,pixels_x),linspace(1,imcol,pixels_y)});
                imwrite(imsf,nufil);
            end

            for ip = 1:length(pdws)
                rowarray = {nufil,pdws(ip).toa,pdws(ip).aoa,pdws(ip).amp, ...
                    pdws(ip).pw,pdws(ip).bw,pdws(ip).fc,pdws(ip).mod };
                pdw_table(end+1,:) = rowarray;
            end
        end
    end
end

varnames = {'imagefile', 'toa', 'aoa', 'amp', 'pw', 'bw', 'fc', 'mod'};
pdw_table.Properties.VariableNames = varnames;
writetable(pdw_table,'DatastorePdws.csv');


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

%%
% This is if imwrite() is being used
% imsf = uint8(zeros(pixels_y,pixels_x,3));

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