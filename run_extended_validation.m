function outputs = run_extended_validation()
%RUN_EXTENDED_VALIDATION Rebuild post-repair external and rolling validation.
%   Run from any working directory with:
%       matlab -batch "run_extended_validation"

    repoRoot = fileparts(mfilename('fullpath'));
    addpath(fullfile(repoRoot, 'src'));
    addpath(fullfile(repoRoot, 'scripts', 'publication'));
    outputs = publication_validation_pipeline(repoRoot, "extended");
end
