// ecology - simulation of a food web-organized world 

// assumptions:
// (1) carbon is both conserved and fully fungible from one form to another
// (2) all organisms are immortal unless they are eaten or starve
// (3) all organisms reproduce by budding
// (4) all animal species exclude cannibalism

import std.stdio; 			// I/O and file system
import std.math; 			// math function library
import std.algorithm; 		// algorithm for working with ranges
import std.array; 			// array operations
import std.string; 			// string function support
import std.conv; 			// automatic conversions between types
import std.typecons; 		// misc. meta-programming support, including type constructors, tuples, etc.
import std.random; 			// for uniform random number generation
import std.range; 			// for enumeration over a range


// *** classes ***

class Domain{

	// general model map characteristics and methods
	int num_x_cells,num_y_cells,line_index;	
	double x_length,y_length,delta_x,delta_y;
	string line_input;
	
	string[] parsed_input;
	
	this(){
		// read input file
		auto input_file = File("world.txt","r");
		while (!input_file.eof()) {
			line_input = input_file.readln();
			if (line_index > 0) { 				// ignore header line in input file 
				parsed_input = split(line_input);
				if (parsed_input[0] == "extent"){ 				// note: model origin is assumed to be (0., 0.)
					this.x_length = to!double(parsed_input[1]);
					this.y_length = to!double(parsed_input[2]);
					}
				else{
					this.num_x_cells = to!int(parsed_input[1]);
					this.num_y_cells = to!int(parsed_input[2]);				
					}
				}
			++line_index;
			}
		input_file.close();	
		this.delta_x = x_length/num_x_cells; 			// cell dimensions
		this.delta_y = y_length/num_y_cells;
		}
	
	int FindCell(double x,double y) {
		// find cell index number for a given (x,y) location
		int col,row,index;
		col = to!int(x/x_length * num_x_cells);		
		row = to!int(y/y_length * num_y_cells);        
		index = row * num_x_cells + col;
		return index;	
		}
	
	}


class Genotype {

	// basic biological characteristics of the organism (i.e., its DNA)
	string species,kingdom,diet_type;
	double carbon_0,carbon_min,carbon_max,carbon_breed,burn,small_meal,big_meal,mobility,spawn_prob;

	this(string species,string kingdom,string diet_type, double carbon_0,double carbon_min,double carbon_max,double carbon_breed,double burn,double small_meal,double big_meal,double mobility, double spawn_prob){
		this.species = species; 				// species name
		this.kingdom = kingdom; 				// animal or plant designation
		this.diet_type = diet_type; 			// diet preference (herbivore,carnivore)
		this.carbon_0 = carbon_0; 				// initial carbon content (i.e., at birth)
		this.carbon_min = carbon_min; 			// minimal carbon content (starvation threshold)
		this.carbon_max = carbon_max; 			// maximum carbon content (obesity threshold)
		this.carbon_breed = carbon_breed; 		// minimum carbon content required for organism to breed (via division)
		this.burn = burn;						// metabolic loss (carbon units over a time step)
		this.small_meal = small_meal; 			// smallest fraction of own (carbon) size organism will eat
		this.big_meal = big_meal; 				// largest fraction of own (carbon) size organism will eat		
		this.mobility = mobility; 				// maximum wander distance per time step
		this.spawn_prob = spawn_prob; 			// spawn frequency (as probability per time step)
	}
}


class Organism {
	// unique characteristics and methods of a particular organism alive in the model

	int cell_index;
	double x,y,carbon,age;
	bool alive,moved;
	Genotype gen;
	
	this(Genotype gen,double x,double y){
		this.gen = gen; 						// genetic characteristics (an object) for this type of organism
		this.x = x;
		this.y = y;
		this.cell_index = 0; 					// placeholder for cell in which organism resides; will be populated later
		this.age = 0.; 						// track organism's age (for output processing)
		this.carbon = gen.carbon_0; 			// assign organism's initial carbon based on genotype's carbon (fixed)
		this.alive = true;
		this.moved = false; 					// flag to indicate if (animal) has moved during this time step
		}
	
	double Metabolize(double meal) {
		// metabolize (happens to the organism independent of location); returns amount of carbon discharged to environment
		double d_carbon,food_waste;
		// mass balance
		d_carbon = gen.burn;								// metabolism (includes exhalation of carbon back to environment)
		carbon -= gen.burn;
		carbon += meal; 								// food intake
		food_waste = max(carbon-gen.carbon_max,0.);		// food waste (correct for excess above organism's limit)
		d_carbon += food_waste;
		carbon -= food_waste;
		if (carbon < gen.carbon_min){ 					// check if organism has starved, and, if so, mark as dead and return all remaining carbon to environment
			alive = false;
			d_carbon += carbon; 		// (this expression will correct for metabolism overshoot to carbon < 0.)
			carbon = 0.;
			} 
		return d_carbon;
		}
	
	void Move(Domain domain){
		// move organism
		double dx,dy,x1,y1;
		dx = uniform(-gen.mobility,gen.mobility);
		dy = uniform(-gen.mobility,gen.mobility);	
		x1 = x + dx;
		y1 = y + dy;
		// implied movements outside model boundaries will be reflected elastically off of boundary
		if (x1 < 0.){dx = -dx - x;}
		if (x1 > domain.x_length){dx = -dx - (domain.x_length - x);}
		if (y1 < 0.){dy = -dy - y;}
		if (y1 > domain.y_length){dy = -dy - (domain.y_length - y);}			
		// update location
		x += dx;
		y += dy;
		cell_index = domain.FindCell(x,y);
		moved = true;
		}	
	
	}


class Cell {

	// distribution of organisms within a model cell, the cell's carbon content, and methods that alter both

	double x,y,carbon,bound_carbon;
	Organism[] animals;
	Organism[] plants;
	
	this(double x,double y,double carbon) {
		this.x = x; 							// cell center coordinates
		this.y = y;
		this.animals = [];						// array of organism objects within cell that are animals (initial placeholder)
		this.plants = []; 						// array of organism objects within cell that are plants (initial placeholder)
		this.carbon = carbon; 					// initial free carbon within the cell
		this.bound_carbon = 0.; 				// total carbon bound to organisms within the cell
		}
	
	void UpdateBound(){
		// update the amount of bound carbon
		bound_carbon = 0.;
		foreach(critter; animals){bound_carbon += critter.carbon;}
		foreach(flora_item; plants){bound_carbon += flora_item.carbon;}
		}
	
	int[string][string] Feed(int[string][string] meal_track){
		// for each animal in cell, select a random suitable item from available meals and eat it; update meal_tracker matrix and return
		int menu_item;
		int[] order;
		Organism meal_select,critter;
		Organism[] menu;
		// obtain a randomly-ordered sequence with which to step through animal list for eating (avoids food availability bias)
		order = RandomList(animals.length);
		for (int i = 0; i < order.length; ++i){
			critter = animals[order[i]];
			menu = FoodList(critter);
			if (menu.length > 0){							// select random item from food list, transfer its carbon, and mark as dead
				menu_item = to!int(uniform(0,menu.length));
				carbon += critter.Metabolize(menu[menu_item].carbon);
				menu[menu_item].alive = false;
				meal_track[menu[menu_item].gen.species][critter.gen.species] += 1;
				}
			else {carbon += critter.Metabolize(0.);}			// nothing to eat!
			}
		return meal_track;
		}
	
	Organism[] FoodList(Organism member){
		// search cell for suitable potential meals (note that member is an animal)
		Organism[] foodlist;
		if (member.gen.diet_type=="herbivore"){
			foreach(flora_item; plants){
				if ((flora_item.alive == true) && (flora_item.carbon >= member.carbon*member.gen.small_meal) && (flora_item.carbon <= member.carbon*member.gen.big_meal)){
					foodlist ~= flora_item; 		// suitable meal; add to menu 
					}
				}
			}
		else{
			foreach(critter; animals){
				if ((critter.alive == true) && (critter.carbon >= member.carbon*member.gen.small_meal) && (critter.carbon <= member.carbon*member.gen.big_meal) && (critter.gen.species != member.gen.species)){
					foodlist ~= critter; 		// suitable meal; add to menu 
					}
				}
			}		
		return foodlist;
		}

	void Photosynthesis(){
		// plant growth - call metabolize function (occurs within cell; consumes cell's carbon)
		double growth;
		int[] order;
		Organism flora_item;
		// obtain a randomly-ordered sequence with which to step through plant list for growth (avoids carbon availability bias)
		order = RandomList(plants.length);
		for (int i = 0; i < order.length; ++i){
			flora_item = plants[order[i]];
			growth = min(carbon,flora_item.carbon*flora_item.gen.small_meal);
			carbon += flora_item.Metabolize(growth) - growth;
			}
		}
	
	}

	
// *** independent functions


Tuple!(Genotype[],int[]) ReadGenotype(){
	// read in organism class characteristics (DNA)
	int line_index;
	double carbon_0,carbon_min,carbon_max,carbon_breed,burn,small_meal,big_meal,mobility,spawn_freq;
	string line_input,species,kingdom,diet_type;
	int[] seeds;
	string[] parsed_input;
	Genotype[] genotype;
	auto input_file = File("genotypes.txt","r");
	while (!input_file.eof()) {
		line_input = input_file.readln();
		if (line_index > 0) { 				// ignore header line in input file 
			parsed_input = split(line_input);
			species = parsed_input[0];
			kingdom = parsed_input[1];
			diet_type = parsed_input[2];
			carbon_0 = to!double(parsed_input[3]);
			carbon_min = to!double(parsed_input[4]);
			carbon_max = to!double(parsed_input[5]);
			carbon_breed = to!double(parsed_input[6]);
			burn = to!double(parsed_input[7]);
			small_meal = to!double(parsed_input[8]);
			big_meal = to!double(parsed_input[9]);
			mobility = to!double(parsed_input[10]);
			spawn_freq = to!double(parsed_input[11]);
			Genotype gen_member = new Genotype(species,kingdom,diet_type,carbon_0,carbon_min,carbon_max,carbon_breed,burn,small_meal,big_meal,mobility,spawn_freq);
			genotype ~= gen_member;	
			seeds ~= to!int(parsed_input[12]);
			}
		++line_index;
		}
	input_file.close();
	return tuple(genotype,seeds);
	}	

	
int[] RandomList(int N){
	// return a randomly ordered sequence of integers (Fisher-Yates shuffle)
	int[] rand_list;
	int[] seeds;
	for (int i = 0; i < N; ++i){rand_list ~= i;}
	randomShuffle(rand_list);
	return rand_list;
	}

Organism[] Breed(Organism[] organism,Cell[] cell,Domain domain){
	// breed via budding (i.e., split exactly in two); happens across all-organism array
	double r;
	Organism[] batch;
	foreach(living_thing;organism){
		r = uniform(0.,1.);
		if ((r < living_thing.gen.spawn_prob) && (living_thing.carbon >- living_thing.gen.carbon_breed)){
			// divide organism
			living_thing.carbon *= 0.5;
			Organism new_thing = new Organism(living_thing.gen,living_thing.x,living_thing.y);
			new_thing.cell_index = living_thing.cell_index;
			new_thing.age = 0.;
			new_thing.carbon = living_thing.carbon;
			// tweak location within cell (to keep daughter plant species from occupying same position as parent)
			new_thing.x = uniform(cell[new_thing.cell_index].x - 0.5*domain.delta_x,cell[new_thing.cell_index].x + 0.5*domain.delta_x);
			new_thing.y = uniform(cell[new_thing.cell_index].y - 0.5*domain.delta_y,cell[new_thing.cell_index].y + 0.5*domain.delta_y);			
			batch ~= new_thing;
			}
		}
	return (organism ~ batch);
	}	
	
	
Tuple!(double,int,int) ReadSettings(){
	// read in model settings
	int print_step,max_steps;
	double total_carbon;
	string line_input;
	string[] parsed_input;
	auto input_file = File("settings.txt","r");
	while (!input_file.eof()) {
		line_input = input_file.readln();
		parsed_input = split(line_input);
		switch (parsed_input[0]) {
			case "total_carbon": 					// total carbon in model, to be divided up among cells
				total_carbon = to!double(parsed_input[1]);
				break;
			case "print_step": 						// printout interval
				print_step = to!int(parsed_input[1]);
				break;		
			default:
				// max steps for model run
				max_steps = to!int(parsed_input[1]);				
				break;
			}
		}
	input_file.close();
	return tuple(total_carbon,print_step,max_steps);
	}		
	
void WriteOrganisms(Cell[] cell, string file_name){
	// write organism-specific output file
	string line_string;
	auto output_file = File(file_name, "w");
	// write header
	line_string = "x" ~ "\t" ~ "y" ~ "\t" ~ "species" ~ "\t" ~ "carbon" ~ "\t" ~ "age";
	output_file.writeln(line_string);
	foreach(area;cell){
		foreach(living_thing;area.plants){
			line_string = to!string(living_thing.x) ~ "\t" ~ to!string(living_thing.y) ~ "\t" ~ living_thing.gen.species ~ "\t" ~ to!string(living_thing.carbon) ~ "\t" ~ to!string(living_thing.age);
			output_file.writeln(line_string);
			}
		foreach(living_thing;area.animals){
			line_string = to!string(living_thing.x) ~ "\t" ~ to!string(living_thing.y) ~ "\t" ~ living_thing.gen.species ~ "\t" ~ to!string(living_thing.carbon) ~ "\t" ~ to!string(living_thing.age);
			output_file.writeln(line_string);
			}			
		}
	output_file.close();
	}	
	
	
void WriteCells(Cell[] cell, string file_name){
	// write cell summary output file
	string line_string;
	auto output_file = File(file_name, "w");
	// write header
	line_string = "x" ~ "\t" ~ "y" ~ "\t" ~ "free_carbon" ~ "\t" ~ "bound_carbon" ~ "\t" ~ "animals" ~ "\t" ~ "plants";
	output_file.writeln(line_string);
	foreach(area;cell){
		line_string = to!string(area.x) ~ "\t" ~ to!string(area.y) ~ "\t" ~ to!string(area.carbon) ~ "\t" ~ to!string(area.bound_carbon) ~ "\t" ~ to!string(area.animals.length) ~ "\t" ~ to!string(area.plants.length);
		output_file.writeln(line_string);
		}
	output_file.close();
	}		
	
void Census(Cell[] cell, Genotype[] genotype, string file_name){
	// write species census output file
	int[string] count; 						// count is an associative array of ints indexed by string keys (i.e., species names)
	for (int i = 0; i < genotype.length; ++i){count[genotype[i].species] = 0;}
	string line_string;
	foreach(area;cell){
		foreach(flora_item;area.plants){count[flora_item.gen.species] += 1;}
		foreach(critter;area.animals){count[critter.gen.species] += 1;}	
		}	
	auto output_file = File(file_name, "w");
	// write header
	line_string = "species" ~ "\t" ~ "count";
	output_file.writeln(line_string);
	foreach(living_thing;genotype){
		line_string = living_thing.species ~ "\t" ~ to!string(count[living_thing.species]);
		output_file.writeln(line_string);
		}
	output_file.close();	
	}

void MealMatrix(Genotype[] genotype,int[string][string] meal_track){
	// write out meal matrix summary
	auto output_file = File("meal_matrix.txt","w");
	string line_string;
	line_string = "victim/eater";
	// write header
	for (int j = 0; j < genotype.length; ++j){ 					// eater list
		if (genotype[j].kingdom == "animal"){line_string ~= "\t" ~ genotype[j].species;}
		}
	output_file.writeln(line_string);		
	// populate output matrix
	for (int i = 0; i < genotype.length; ++i){ 					// victim list
		line_string = genotype[i].species;
		for (int j = 0; j < genotype.length; ++j){ 					// eater list
			if (genotype[j].kingdom == "animal"){line_string ~= "\t" ~ to!string(meal_track[genotype[i].species][genotype[j].species]);}
			}		
		output_file.writeln(line_string);
		}
	output_file.close();	
	}
	
	
// *** main program


void main(){

	int init_cell_index,print_step,max_steps;
	double cell_carbon,x,y,total_carbon;
	string file_name;
	
	int[] seeds;
	int[string][string] meal_track; 			// associative array to track food web; key = [victim][eater]
	
	Organism item;
	Domain domain;
	
	Genotype[] genotype;
	Cell[] cell;
	
	// read settings input file
	auto settings = ReadSettings();
	total_carbon = settings[0];		// total model carbon
	print_step = settings[1];		// print interval
	max_steps = settings[2];		// end step
	writeln("Read model settings.");	
	
	// read in general model geometry
	domain = new Domain();
	writeln("Read general model geometry.");
	
	// create cells
	cell_carbon = total_carbon/(domain.num_x_cells*domain.num_y_cells);
	for (int j = 0; j < domain.num_y_cells; ++j){
		for (int i = 0; i < domain.num_x_cells; ++i){
			x = (i + 0.5) * domain.delta_x;
			y = (j + 0.5) * domain.delta_y;
			Cell cell_member = new Cell(x,y,cell_carbon);
			cell ~= cell_member;
			}
		}
	writeln("Created cells.");	
	
	// read and assign genotypes 
	auto life = ReadGenotype();
	genotype = life[0]; 			// list genotype objects
	seeds = life[1];				// list of initial organism populations
	for (int i = 0; i < genotype.length; ++i){
		for (int j = 0; j < genotype.length; ++j){
			if (genotype[j].kingdom == "animal"){
				meal_track[genotype[i].species][genotype[j].species] = 0; 		// initialize meal tracker matrix
				}
			}
		}
	writeln("Read genotypes.");
	
	// loop through all organism seeds and assign to cells
	for (int i = 0; i < seeds.length; ++i){
		for (int j = 0; j < seeds[i]; ++j){
			x = uniform(0,domain.x_length);
			y = uniform(0,domain.y_length);
			Organism organism_member = new Organism(genotype[i],x,y);
			organism_member.cell_index = domain.FindCell(x,y);
			if (genotype[i].kingdom == "animal"){cell[organism_member.cell_index].animals ~= organism_member;}
			else{cell[organism_member.cell_index].plants ~= organism_member;}
			}
		}
	writeln("Populated cells.");	
	
	// write out initial conditions to files
	WriteOrganisms(cell,"org_initial.txt");
	WriteCells(cell,"cell_initial.txt");
	Census(cell,genotype,"census_initial.txt");
	
	// time-step loop
	for (int istep = 0; istep < max_steps; ++istep){
	
		writeln("Beginning step ",to!string(istep+1));
	
		// (1) feeding and growth (life step #1)	
		foreach(area;cell){
			meal_track = area.Feed(meal_track);
			area.Photosynthesis();
			}				
	
		// (2) remove all dead organisms from model for each cell (stepping backwards)
		foreach(area;cell){
			for (int j = area.animals.length - 1; j >= 0; --j){
				if (area.animals[j].alive == false){area.animals = remove(area.animals,j);}
				}
			for (int j = area.plants.length - 1; j >= 0; --j){
				if (area.plants[j].alive == false){area.plants = remove(area.plants,j);}
				}	
			}
			
		// (3) breeding (all organisms; handled within Breed function)
		foreach(area;cell){
			area.animals = Breed(area.animals,cell,domain);
			area.plants = Breed(area.plants,cell,domain);
			}

		// (4) movement
		foreach(area;cell){
			for (int i = area.animals.length - 1; i >= 0; --i){
				if (area.animals[i].moved == false){
					init_cell_index = area.animals[i].cell_index;
					area.animals[i].Move(domain);
					if (area.animals[i].cell_index != init_cell_index){
						// animal has moved to a different cell
						item = area.animals[i];
						area.animals = remove(area.animals,i);
						cell[item.cell_index].animals ~= item;						
						//move(area.animals[i],cell[item.cell_index].animals);
						}
					}
				else {area.animals[i].moved = false;} 	// uncheck moved flag (for next time step) and move on to next animal on list
				}
			}

		// (5) update ages
		foreach(area;cell){
			foreach(living_thing;area.animals){living_thing.age += 1.;}
			foreach(living_thing;area.plants){living_thing.age += 1.;}			
			}
		
		// (6) write to output file, if warranted
		if ((istep+1) % print_step == 0) {
			foreach(area;cell){area.UpdateBound();} 				// update bound carbon in each cell
			file_name = "step_" ~ to!string(istep) ~ "_census.txt";			
			Census(cell,genotype,file_name);			
			file_name = "step_" ~ to!string(istep) ~ "_org.txt";
			WriteOrganisms(cell,file_name);
			file_name = "step_" ~ to!string(istep) ~ "_cell.txt";
			WriteCells(cell,file_name);
			}
	
		}
	
	// summarize food web links for simulation
	MealMatrix(genotype,meal_track);
	
	writeln("Done.");
	
	}



