function varargout = process_convert_raw_to_lfp_MOTOR_LAB( varargin )
% PROCESS_CONVERT_RAW_TO_LFP: Convert the raw signals after spike sorting
% to LFP signals.
% The user has the option to perform Bayesian Spike Removal, a method
% described in: https://www.ncbi.nlm.nih.gov/pubmed/21068271

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
% Authors: Konstantinos Nasiotis 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Convert Raw to Binary';
    sProcess.Category    = 'custom';
    sProcess.SubGroup    = 'Dancause Lab';
    sProcess.Index       = 1803;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/e-phys/RawToLFP';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'raw'};
    sProcess.OutputTypes = {'raw'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    sProcess.processDim  = 1;    % Process channel by channel

    % Definition of the options    
    sProcess.options.paral.Comment     = 'Parallel processing';
    sProcess.options.paral.Type        = 'checkbox';
    sProcess.options.paral.Value       = 1;
    
    sProcess.options.binsizeHelp.Comment = '<I><FONT color="#777777">The memory value below will be used in case the channels were not separated</FONT></I>';
    sProcess.options.binsizeHelp.Type    = 'label';
    
    sProcess.options.binsize.Comment = 'Memory to use for demultiplexing';
    sProcess.options.binsize.Type    = 'value';
    sProcess.options.binsize.Value   = {1, 'GB', 1}; % This is used in case the electrodes are not separated yet (no spike sorting done), ot the temp folder was emptied 
    
end



%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs, method) %#ok<DEFNU>
    OutputFiles = {};
    
    for iInput = 1:length(sInputs)
        sInput = sInputs(iInput);
        %% Parameters
        
        % Get method name
        if (nargin < 3)
            method = [];
        end

        
        % Prepare parallel pool, if requested
        if sProcess.options.paral.Value
            try
                poolobj = gcp('nocreate');
                if isempty(poolobj)
                    parpool;
                end
            catch
                sProcess.options.paral.Value = 0;
                poolobj = [];
            end
        else
            poolobj = [];
        end

        %% Initialize

        % Prepare output file
        ProtocolInfo = bst_get('ProtocolInfo');
        newCondition = [sInput.Condition, '_BST'];
        sMat = in_bst(sInput.FileName, [], 0);
        Fs = 1 / diff(sMat.Time(1:2)); % This is the original sampling rate
        
        NewFreq = Fs;

        % Get new condition name
        newStudyPath = file_unique(bst_fullfile(ProtocolInfo.STUDIES, sInput.SubjectName, newCondition));
        % Output file name derives from the condition name
        [tmp, rawBaseOut, rawBaseExt] = bst_fileparts(newStudyPath);
        rawBaseOut = strrep([rawBaseOut rawBaseExt], '@raw', '');
        % Full output filename
        RawFileOut = bst_fullfile(newStudyPath, [rawBaseOut '.bst']); % ***
        RawFileFormat = 'BST-BIN'; % ***
        ChannelMat = in_bst_channel(sInput.ChannelFile); % ***
        nChannels = length(ChannelMat.Channel);
        % Get input study (to copy the creation date)
        sInputStudy = bst_get('AnyFile', sInput.FileName);

        sStudy = bst_get('ChannelFile', sInput.ChannelFile);
        [tmp, iSubject] = bst_get('Subject', sStudy.BrainStormSubject, 1);

        % Get new condition name
        [tmp, ConditionName] = bst_fileparts(newStudyPath, 1);
        % Create output condition
        iOutputStudy = db_add_condition(sInput.SubjectName, ConditionName, [], sInputStudy.DateOfStudy);

        ChannelMatOut = ChannelMat;
        sFileTemplate = sMat.F;

        %% Get the transformed channelnames that were used on the signal data naming. This is used in the derive lfp function in order to find the spike events label
        % New channelNames - Without any special characters.
        cleanChannelNames = str_remove_spec_chars({ChannelMat.Channel.Name});

        %% Update fields before initializing the header on the binary file
        sFileTemplate.prop.sfreq = Fs;
        sFileTemplate.header.sfreq = Fs;
        sFileTemplate.header.nsamples = round((sFileTemplate.prop.times(2) - sFileTemplate.prop.times(1)) .* NewFreq) + 1;

        % Update file
        sFileTemplate.CommentTag     = sprintf('resample(%dHz)', round(NewFreq));

        % Convert events to new sampling rate
        newTimeVector = panel_time('GetRawTimeVector', sFileTemplate);

        %% Create an empty Brainstorm-binary file and assign the correct samples-times
        % The sFileOut is what will be the final 
        [sFileOut, errMsg] = out_fopen(RawFileOut, RawFileFormat, sFileTemplate, ChannelMat);


        %% Check if the files are separated per channel. If not do it now.
        % These files will be converted to LFP right after
        sFiles_temp_mat = in_spikesorting_rawelectrodes(sInput, sProcess.options.binsize.Value{1}(1) * 1e9, sProcess.options.paral.Value);

        %% Filter and derive LFP
        LFP = zeros(length(sFiles_temp_mat), length(downsample(sMat.Time,round(Fs/NewFreq)))); % This shouldn't create a memory problem
        bst_progress('start', 'Dancause Lab', 'Converting RAW signals to BST...', 0, (sProcess.options.paral.Value == 0) * nChannels);

        if sProcess.options.paral.Value
            parfor iChannel = 1:nChannels
                LFP(iChannel,:) = filter_and_downsample(sFiles_temp_mat{iChannel});
            end
        else
            for iChannel = 1:nChannels
                LFP(iChannel,:) = filter_and_downsample(sFiles_temp_mat{iChannel});
                bst_progress('inc', 1);
            end
        end
        
        % WRITE OUT
        sFileOut = out_fwrite(sFileOut, ChannelMatOut, [], [], [], LFP);

        % Import the RAW file in the database viewer and open it immediately
        RawFile = import_raw({sFileOut.filename}, 'BST-BIN', iSubject);
        RawFile = RawFile{1};
        
        % Modify it slightly since this is an LFP raw file
        [sStudy, iStudy] = bst_get('DataFile', RawFile);
        RawMat = load(RawFile);
        RawMat.Comment = 'Link to BST file';
        RawNewFile = strrep(RawFile, 'data_0raw', 'data_0lfp');
        bst_save(RawNewFile, RawMat, 'v6');
        OutputFiles{end + 1} = RawNewFile;
        delete(RawFile);
        db_reload_studies(iStudy);
    end
end


function data = filter_and_downsample(inputFilename)
    sMat = load(inputFilename); % Make sure that a variable named data is loaded here. This file is saved as an output from the separator 
    
    data = sMat.data';
end


