function tooHighATP = plotATPTestResults(refinedFolder, varargin)
% This function plots the maximal ATP yield by refined reconstructions and
% reports whether ATP production is feasible. Optionally, draft
% reconstructions can be included.
%
% USAGE:
%
%    tooHighATP = plotATPTestResults(refinedFolder, varargin)
%
%
% REQUIRED INPUTS
% refinedFolder             Folder with refined COBRA models generated by the
%                           refinement pipeline
% OPTIONAL INPUTS
% testResultsFolder         Folder where the test results should be saved
%                           (default: current folder)
% reconVersion              Name of the refined reconstruction resource
%                           (default: "Reconstructions")
% numWorkers                Number of workers in parallel pool (default: 0)
% translatedDraftsFolder    Folder with  translated draft COBRA models generated by KBase
%                           pipeline to analyze (will only be analyzed if
%                           folder is provided)
% OUTPUT
% tooHighATP                List of IDs for refined reconstructions that
%                           produce too much ATP on Western diet
%
% .. Authors:
%       - Almut Heinken, 09/2020

% Define default input parameters if not specified
parser = inputParser();
parser.addRequired('refinedFolder', @ischar);
parser.addParameter('testResultsFolder', [pwd filesep 'TestResults']', @ischar);
parser.addParameter('numWorkers', 0, @isnumeric);
parser.addParameter('reconVersion', 'Reconstructions', @ischar);
parser.addParameter('translatedDraftsFolder', '', @ischar);

parser.parse(refinedFolder, varargin{:});

refinedFolder = parser.Results.refinedFolder;
testResultsFolder = parser.Results.testResultsFolder;
numWorkers = parser.Results.numWorkers;
reconVersion = parser.Results.reconVersion;
translatedDraftsFolder = parser.Results.translatedDraftsFolder;

mkdir(testResultsFolder)

tooHighATP = {};
cnt=1;

% initialize COBRA Toolbox and parallel pool
global CBT_LP_SOLVER
if isempty(CBT_LP_SOLVER)
    initCobraToolbox
end
solver = CBT_LP_SOLVER;

if numWorkers > 0
    % with parallelization
    poolobj = gcp('nocreate');
    if isempty(poolobj)
        parpool(numWorkers)
    end
end
environment = getEnvironment();

if ~isempty(translatedDraftsFolder)
    % test draft and refined reconstructions
    folders={
        translatedDraftsFolder
        refinedFolder
        };
else
    % only refined reconstructions
    folders={
        refinedFolder
        };
end

for f=1:length(folders)
    dInfo = dir(folders{f});
    modelList={dInfo.name};
    modelList=modelList';
    modelList(~contains(modelList(:,1),'.mat'),:)=[];
    
    parfor i=1:length(modelList)
        restoreEnvironment(environment);
        changeCobraSolver(solver, 'LP', 0, -1);
        
        model=readCbModel([folders{f} filesep modelList{i}]);
        biomassID=find(strncmp(model.rxns,'bio',3));
        [atpFluxAerobic, atpFluxAnaerobic] = testATP(model);
        aerRes{i,f}=atpFluxAerobic;
        anaerRes{i,f}=atpFluxAnaerobic;
    end
    
    for i=1:length(modelList)
        atp{f}(i,1)=aerRes{i,f};
        atp{f}(i,2)=anaerRes{i,f};
    end
end

data=[];
for f=1:length(folders)
    data(:,size(data,2)+1:size(data,2)+2)=atp{f}(:,1:2);
end


if ~isempty(translatedDraftsFolder)
    % draft and refined reconstructions
    figure;
    hold on
    violinplot(data, {'Aerobic, Draft','Anaerobic, Draft','Aerobic, Refined','Anaerobic, Refined'});
    set(gca, 'FontSize', 12)
    box on
    h=title(['ATP production on Western diet, ' reconVersion]);
    set(h,'interpreter','none')
    set(gca,'TickLabelInterpreter','none')
    print([testResultsFolder filesep 'ATP_Western_diet_' reconVersion],'-dpng','-r300')
    
    % report draft models that produce too much ATP
    fprintf('Report for draft models:\n')
    tooHigh=atp{1}(:,1) > 150;
    if sum(tooHigh) > 0
        fprintf([num2str(sum(tooHigh)) '  models produce too much ATP under aerobic conditions.\n'])
    else
        fprintf('All models produce reasonable amounts of ATP under aerobic conditions.\n')
    end
    
    tooHigh=atp{1}(:,2) > 100;
    if sum(tooHigh) > 0
        fprintf([num2str(sum(tooHigh)) '  models produce too much ATP under anaerobic conditions.\n'])
    else
        fprintf('All models produce reasonable amounts of ATP under anaerobic conditions.\n')
    end
    
    % report refined models that produce too much ATP
    fprintf('Report for refined models:\n')
    tooHigh=atp{2}(:,1) > 150;
    if sum(tooHigh) > 0
        fprintf([num2str(sum(tooHigh)) '  models produce too much ATP under aerobic conditions.\n'])
        for i=1:length(tooHigh)
            tooHighATP{cnt,1}=modelList{tooHigh(i),1};
            cnt=cnt+1;
        end
    else
        fprintf('All models produce reasonable amounts of ATP under aerobic conditions.\n')
    end
    
    tooHigh=atp{2}(:,2) > 100;
    if sum(tooHigh) > 0
        fprintf([num2str(sum(tooHigh)) '  models produce too much ATP under anaerobic conditions.\n'])
        for i=1:length(tooHigh)
            tooHighATP{cnt,1}=modelList{tooHigh(i),1};
            cnt=cnt+1;
        end
    else
        fprintf('All models produce reasonable amounts of ATP under anaerobic conditions.\n')
    end
    
else
    % only refined reconstructions
    figure;
    hold on
    violinplot(data, {'Aerobic','Anaerobic'});
    set(gca, 'FontSize', 12)
    box on
    h=title(['ATP production on Western diet, ' reconVersion]);
    set(h,'interpreter','none')
    set(gca,'TickLabelInterpreter','none')
    print([testResultsFolder filesep 'ATP_Western_diet_' reconVersion],'-dpng','-r300')
end

% report refined models that produce too much ATP
fprintf('Report for refined models:\n')
tooHigh=atp{1}(:,1) > 150;
if sum(tooHigh) > 0
    fprintf([num2str(sum(tooHigh)) '  models produce too much ATP under aerobic conditions.\n'])
    for i=1:length(tooHigh)
        if tooHigh(i)
            tooHighATP{cnt,1}=modelList{i,1};
            cnt=cnt+1;
        end
    end
else
    fprintf('All models produce reasonable amounts of ATP under aerobic conditions.\n')
end

tooHigh=atp{1}(:,2) > 100;
if sum(tooHigh) > 0
    fprintf([num2str(sum(tooHigh)) '  models produce too much ATP under anaerobic conditions.\n'])
    for i=1:length(tooHigh)
        if tooHigh(i)
            tooHighATP{cnt,1}=modelList{i,1};
            cnt=cnt+1;
        end
    end
else
    fprintf('All models produce reasonable amounts of ATP under anaerobic conditions.\n')
end

tooHighATP=unique(tooHighATP);
tooHighATP=strrep(tooHighATP,'.mat','');
save([testResultsFolder filesep 'tooHighATP.mat'],'tooHighATP');

end
