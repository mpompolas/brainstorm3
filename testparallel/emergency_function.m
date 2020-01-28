function emergency_function(folder, currentJobIdentifier)

    
%% Get the files that are already computed    
% If folder doesn't exist, create a new one
if ~exist(fullfile(folder,['temp_' currentJobIdentifier]), 'dir')
    error(['The temp folder for job: ' currentJobIdentifier ' doesnt exist. Something is off'])
end

all_files = dir(fullfile(folder,['temp_' currentJobIdentifier]));
all_fileNames = {all_files.name};
all_fileNames = all_fileNames(~ismember(all_fileNames,{'.','..'}));


fileTypes = {'in_progress', 'completed'};

collection = cell(1,2);

for iType = 1:length(fileTypes)
    indicesTypes = contains(all_fileNames, fileTypes{iType});
    collection{iType} = str2double(erase(all_fileNames(indicesTypes),fileTypes{iType}));
end

iConflicts = collection{1}(find(~ismember(collection{1},collection{2})));

for iFile = 1:length(iConflicts)
    delete(fullfile(folder,['temp_' currentJobIdentifier], ['in_progress',num2str(iConflicts(iFile))]),'s');
end


end