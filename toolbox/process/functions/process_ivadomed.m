function varargout = process_ivadomed( varargin )

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<*DEFNU>
    % Description the process
    sProcess.Comment     = 'Ivadomed';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'IvadoMed Toolbox';
    sProcess.Index       = 3112;
    sProcess.Description = 'https://ivadomed.org/en/latest/index.html';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % Event name
    sProcess.options.eventname.Comment = 'Event for ground truth';
    sProcess.options.eventname.Type    = 'text';
    sProcess.options.eventname.Value   = 'expert annotated event';
    
    
    % Method: Average or PCA
    sProcess.options.label1.Comment = '<BR>Command to execute:';
    sProcess.options.label1.Type    = 'label';
    sProcess.options.command.Comment = {'Training', 'Testing', 'Segmentation'};
    sProcess.options.command.Type    = 'radio';
    sProcess.options.command.Value   = 1;
    
    % File selection options
    SelectOptions = {...
        '/tmp/spinegeneric', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Import anatomy folder...', ...    % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'dirs', ...                        % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'AnatIn'), ... % Available file formats
        'AnatIn'};                         % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    
    % Use existing SSPs
    sProcess.options.usessp.Comment = 'Debugging';
    sProcess.options.usessp.Type    = 'checkbox';
    sProcess.options.usessp.Value   = 1;
    % Event name
    sProcess.options.gpu.Comment = 'GPU IDs: ';
    sProcess.options.gpu.Type    = 'text';
    sProcess.options.gpu.Value   = '1, 2, 3';
    % Option: Dataset Selection
    sProcess.options.output.Comment = 'Output Folder:';
    sProcess.options.output.Type    = 'filename';
    sProcess.options.output.Value   = SelectOptions;
    
    
    % Default selection of components
    sProcess.options.gpu.Comment = 'GPU IDs: ';
    sProcess.options.gpu.Type    = 'value';
    sProcess.options.gpu.Value   = {[1,2,3], 'list', 0};
     % Method: Average or PCA
    sProcess.options.label3.Comment = '<BR>Model selection:';
    sProcess.options.label3.Type    = 'label';
    sProcess.options.modelselection.Comment = {'default_model'; 'FiLMedUnet'; 'HeMISUnet'; 'Modified3DUNet'};
    sProcess.options.modelselection.Type    = 'radio';
    sProcess.options.modelselection.Value   = 1;
    
    % File selection options
    SelectOptions = {...
        '/data/large-dataset-testing', ...                            % Filename
        '', ...                            % FileFormat
        'open', ...                        % Dialog type: {open,save}
        'Import anatomy folder...', ...    % Window title
        'ImportAnat', ...                  % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
        'single', ...                      % Selection mode: {single,multiple}
        'dirs', ...                        % Selection mode: {files,dirs,files_and_dirs}
        bst_get('FileFilters', 'AnatIn'), ... % Available file formats
        'AnatIn'};                         % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,AnatIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn}
    % Option: Dataset Selection
    sProcess.options.dataset.Comment = 'BIDS Folder (path_data):';
    sProcess.options.dataset.Type    = 'filename';
    sProcess.options.dataset.Value   = SelectOptions;
    % Multichannel
    sProcess.options.multichannel.Comment = 'Multichannel';
    sProcess.options.multichannel.Type    = 'checkbox';
    sProcess.options.multichannel.Value   = 0;
    % Multichannel
    sProcess.options.softgt.Comment = 'Soft groundtruth';
    sProcess.options.softgt.Type    = 'checkbox';
    sProcess.options.softgt.Value   = 1;
    % Method: Average or PCA
    sProcess.options.label2.Comment = '<BR>Slice Axis:';
    sProcess.options.label2.Type    = 'label';
    sProcess.options.sliceaxis.Comment = {'Axial'; 'Sagittal'; 'Coronal'};
    sProcess.options.sliceaxis.Type    = 'radio';
    sProcess.options.sliceaxis.Value   = 1;
    
    % Event name
    sProcess.options.loss.Comment = 'Loss function: ';
    sProcess.options.loss.Type    = 'text';
    sProcess.options.loss.Value   = 'DiceLoss';
    
    % Multichannel
    sProcess.options.label4.Comment = '<BR>Uncertainty';
    sProcess.options.label4.Type    = 'label';
    sProcess.options.epistemic.Comment = 'Epistemic';
    sProcess.options.epistemic.Type    = 'checkbox';
    sProcess.options.epistemic.Value   = 1;
    sProcess.options.aleatoric.Comment = 'Aleatoric';
    sProcess.options.aleatoric.Type    = 'checkbox';
    sProcess.options.aleatoric.Value   = 0;
    
    % Trick to fake spikesorter - THIS NEEDS TO BE CHANGED
    sProcess.options.spikesorter.Type   = 'text';
    sProcess.options.spikesorter.Value  = 'ivadomed';
    sProcess.options.spikesorter.Hidden = 1;
    
    % Options: Options
    sProcess.options.edit.Comment = {'panel_spikesorting_options', '<U><B>Config file</B></U>: '};
    sProcess.options.edit.Type    = 'editpref';
    sProcess.options.edit.Value   = [];
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)
    if isfield(sProcess.options, 'modelselection') && ~isempty(sProcess.options.modelselection.Value)
        Comment = ['Ivadomed: ' sProcess.options.modelselection.Comment{sProcess.options.modelselection.Value}];
    else
        Comment = 'Ivadomed';
    end
end


%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs)
    % Process each RAW file separately
    OutputFiles = {};
    % Check for multiple files of the same channel file
    uniqueChannel = unique({sInputs.ChannelFile});
    if (length(uniqueChannel) ~= length(sInputs))
        bst_report('Error', sProcess, sInputs, ...
            ['The files you selected share the same channel file. This process considers each file independently, ' 10 ...
             'and requires the multiple input files to be using different channel files. Each file will result ' 10 ...
             'into one new category of SSP projectors in its channel file.' 10 10 ...
             'To calculate the SSP from multiple runs and/or save the results into one channel file only, ' 10 ...
             'please use the corresponding SSP process from the Process2 tab.']);
        return;
    end
    % Call recursively the function on each RAW file
    for iFile = 1:length(sInputs)
        OutputFiles = cat(2, OutputFiles, process_ssp2('Run', sProcess, sInputs(iFile), sInputs(iFile)));
    end
end


