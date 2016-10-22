# ecology_food_web
This is a D-language-based simulator written purely as a fun exercise; it takes advantage of a few simple object-oriented programming concepts but executes faster than Python. Speed is important, because a large number of organisms can exist in the model at certain times.
The simulator is based on a food web concept, where carnivores eat other carnivores as well as herbivores, which of course eat plants. All the creatures in the model reproduce, and the animals are free to move around within a model grid. Feed size constraints and metabolic rates are specified to influence behavior.

The following tab-delimited input files are required:

* genotypes.txt - plant and animal attributes (growth rate, diet, etc.), plus initial population size
* settings.txt - initial carbon, number of time steps
* world.txt - grid setup

More background information can be found here: https://numericalenvironmental.wordpress.com/2016/07/11/ecology-model/

Email me with questions at walt.mcnab@gmail.com. 
