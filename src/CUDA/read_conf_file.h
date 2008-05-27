/*
** read_conf_file.h
** 
** Made by Matthieu Ospici
** Login   <mo219174@muscade>
** 
** Started on  Wed May 21 14:22:40 2008 Matthieu Ospici
** Last update Wed May 21 14:22:40 2008 Matthieu Ospici
*/

#ifndef   	READ_CONF_FILE_H_
# define   	READ_CONF_FILE_H_

#include <map>
#include <string>

typedef std::map<std::string , std::string> mapFile_t;

class e_matt_base{};
class file_not_found : public e_matt_base{};
class read_not_found : public e_matt_base{};



template<typename T>
T strTo(const std::string& str)
{
  T dest;
  std::istringstream iss( str );
  iss >> dest;
  return dest;
}



class readConfFile
{
public:
  readConfFile( const std::string& filename) throw(file_not_found);
  void get(const std::string& key, std::string& value) const throw(read_not_found)  ;

  
private:
  mapFile_t mFile;
};


class read_not_found_GPU : public read_not_found{};
class read_not_found_CPU : public read_not_found{};



class readConfFileGPU_CPU : public readConfFile
{
public:
  readConfFileGPU_CPU( const std::string& filename) : readConfFile(filename){};

  int getGPU(int MPI_ID) const throw(read_not_found_GPU);
  int getCPU(int MPI_ID) const throw(read_not_found_CPU);
  int getFlag(int MPI_ID) const throw(); //0 CUDA, 1 BLAS
};

#endif 	    /* !READ_CONF_FILE_H_ */
