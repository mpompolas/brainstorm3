function F = in_fread_tdt(sFile, SamplesBounds, selectedChannels)



%% IN_FOPEN_TDT: Open recordings saved in the Tucker Davis Technologies format


 %% 
 % @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Author: Konstantinos Nasiotis 2019


% IN_FREAD_TDT Read a block of recordings from TDT files
%
% USAGE:  F = in_fread_TDT(sFile, SamplesBounds=[], iChannels=[])

 % @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Author: Konstantinos Nasiotis 2019, 2020


 % Parse inputs
if (nargin < 3) || isempty(selectedChannels)
    selectedChannels = 1:length(sFile.channelflag);
end
if (nargin < 2) || isempty(SamplesBounds)
    SamplesBounds = round(sFile.prop.times .* sFile.prop.sfreq);
end

nChannels = length(selectedChannels);
nSamples = SamplesBounds(2) - SamplesBounds(1) + 1;

Fs = ceil(max([sFile.header.stream_info.fs]));


%% The importer for TDT, imports based on timeBounds, not samplebounds
% This is a nightmare when trying to load segments of the same length
% Especially since some channels are sampled at a different sampling rate
% The code below upsamples the signals with lower Fs to match the sampling
% rate of the highest sampled signal (typically LFP or Raw)
% This might create a problem at certain datasets.

stream_info = sFile.header.stream_info;
nChannels   = sum([sFile.header.stream_info.total_channels]);


tic
data = TDTbin2mat(sFile.filename, 'TYPE', 4, 'T1', SamplesBounds(1)/Fs, 'T2', SamplesBounds(2)/Fs);
toc

F = zeros(length(selectedChannels), nSamples);
ii = 1;
for iStream = 1:length(stream_info)

    % DO THE EXTRAPOLATION HERE FOR THE LOW SAMPLED SIGNALS (EYE TRACES, ARM MOVEMENTS ETC.)
    if ceil(stream_info(iStream).fs) ~= Fs
        
        
        low_sampled_signal = double(data.streams.(stream_info(iStream).label).data);
        
        temp = zeros(size(low_sampled_signal,1),nSamples);
        for iChannel = 1:size(low_sampled_signal,1)
            
            %1. UPSAMPLE AND DROP RANDOM ENTRIES
            % Upsampling the lower sampled behavioral signals
            upsampled_position = repelem(low_sampled_signal(iChannel,:),ceil(nSamples/length(low_sampled_signal)));
            logical_keep = true(1,length(upsampled_position));
            random_points_to_remove = randperm(length(upsampled_position),length(upsampled_position)-nSamples);
            logical_keep(random_points_to_remove) = false;
            temp(iChannel,:) = upsampled_position(logical_keep);
            
%             %2. INTERPOLLATION
%             temp(iChannel,:) = interp(double(data.streams.(stream_info(iStream).label).data),round(Fs/stream_info(iStream).fs));

        end
        
        
    else
        temp = double(data.streams.(stream_info(iStream).label).data);
    end

    % At the end of the signals' length, since the loading based on time is awful,
    % leave the extra samples as zeros (shouldn't create a problem)
    if nSamples > size(temp,2)
        F(ii : ii + stream_info(iStream).total_channels - 1,1:size(temp,2)) = temp; clear temp
    else  
        F(ii : ii + stream_info(iStream).total_channels - 1,:) = temp(:,1:nSamples); clear temp
    end
    ii = ii + stream_info(iStream).total_channels;
end



% Lazy selection, Improve
F = F(selectedChannels,:);
      

end





