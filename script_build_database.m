
radarml_home = '/ws1/itar/WaveGen/RadarML/';
dynamicRange_dB = 30;

% The files of data collected by ARESTOR 
arestor_file = dir([radarml_home,'/UCLRESM/*.npy']);

% Spectrogram fft length and overlap
fft_length = 60;
fft_overlap = 30;

%{ 
Image size - this is set to 227x227 for the pre-trained squeezenet
architecture. If using other architectures, then these may need to be
adjusted.
%}
pixels_x = 227;
pixels_y = 227;

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
    sig = iq(s0:s1);
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
    nufil = ['./tempDatabase/',namod,'/',arestor_file(n).name];
    nufil(end-3:end) = '.png';
    exportgraphics(fig,nufil,Units="pixels",Width=pixels_x,Height=pixels_y);
    close(gcf);
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
