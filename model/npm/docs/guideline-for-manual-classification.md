# Guideline to manually classify NPM projects 

AboutCode has selected an open source expert to evaluate 200 components from a set with the most popular NPM packages. The packages were obtained from Census II, Census III and deps.dev. See [this link](https://github.com/aboutcode-org/scancode.io/issues/2165#issuecomment-4535819656) for more information.

The expert is not allowed to see the scores to avoid a biased evaluation. We list below the basic parameters the expert used for the evaluation to identify unhealthy NPM components, that way we ease a review by other experts.

## Parameters

The following list shows the different parameters used by the expert to manually tag each of the projects.

1. Last commit available and commits during the last 24 and 12 months  
2. Developers active in Git commits in the last 12 months  
3. Size of the project in lines of code (SLOC)  
4. User base according to https://www.npmjs.com/. A module with a small user base will get less feedback. It is also true that a big user base will mean that more malicious attackers will try to gain access to the project.  
5. Number of runtime dependencies.   
6. Declared OSS license  
7. The package has pre and post install scripts. Not including them is a good practice. [https://docs.npmjs.com/cli/v11/using-npm/scripts\#best-practices](https://docs.npmjs.com/cli/v11/using-npm/scripts#best-practices)  
8. A maintainer’s email address is associated with an expired domain. This is relevant as it can be used to impersonate the maintainer email address and get access to the project.

## Bad smells

In software engineering, a "bad smell" (more commonly known as a code smell) is a surface-level indicator that there might be a deeper problem in your system's design or source code. We extend this definition to other areas out of software engineering and for cases with unexpected behaviours.

Our expert has used the following bad smells to categorize projects between risky and non-risky

1. Git activity and SLOC:  
   1. No activity in > 3 years for a tiny project (< 100 SLOC) is a bad smell.  
   2. No activity in > 18 months for a small/medium project (< 5K SLOC, >100 SLOC) is a bad smell.   
   3. No activity in > 6 months for a big project is a bad smell (> 5K SLOC)  
2. SLOC and active developers:  
   1.  A project with +10K SLOC and a single developer is a bad smell  
3. Number of runtime dependencies:  
   1. A project that is close to have a bad smell in any of the other categories, with a number of runtime dependencies bigger than 0 will trigger a bad smell.  
4. Declared OSS license  
   1. Not having a valid OSS license is a bad smell.  
5. The package has pre and post install scripts  
   1. A project that is close to have a bad smell in any of the other categories, with a pre or post install script will trigger a bad smell  
6. A maintainer’s email address is associated with an expired domain. This will trigger a bad smell.

