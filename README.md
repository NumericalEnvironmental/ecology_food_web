# ecology_food_web

![Preview](https://numericalenvironmental.files.wordpress.com/2016/07/organism_distribution.jpg?w=616)

This is a D-language-based simulator written purely as a fun exercise; it takes advantage of a few simple object-oriented programming concepts but executes faster than Python. Speed is important, because a large number of organisms can exist in the model at certain times.
The simulator is based on a food web concept, where carnivores eat other carnivores as well as herbivores, which of course eat plants. All the creatures in the model reproduce, and the animals are free to move around within a model grid. Feed size constraints and metabolic rates are specified to influence behavior.

The following tab-delimited input files are required:

* genotypes.txt - plant and animal attributes (growth rate, diet, etc.), plus initial population size
* settings.txt - initial carbon, number of time steps
* world.txt - grid setup

More background information can be found here: https://numericalenvironmental.wordpress.com/2016/07/11/ecology-model/

I'd appreciate hearing back from you if you find the script useful. Questions or comments are welcome at walt.mcnab@gmail.com. 

THIS CODE/SOFTWARE IS PROVIDED IN SOURCE OR BINARY FORM "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
