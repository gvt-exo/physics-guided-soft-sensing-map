function outputs = run_publication_validation()
%RUN_PUBLICATION_VALIDATION Rebuild all publication validation artifacts.
%   Run from any working directory with:
%       matlab -batch "run_publication_validation"

    repoRoot = fileparts(mfilename('fullpath'));
    addpath(fullfile(repoRoot, 'src'));
    addpath(fullfile(repoRoot, 'scripts', 'publication'));

    outputs = publication_validation_pipeline(repoRoot);
end
