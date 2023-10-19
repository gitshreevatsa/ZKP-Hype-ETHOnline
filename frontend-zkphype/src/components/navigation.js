import './navigation.css';
import { Navigate, useNavigate, useNavigation } from 'react-router-dom';
function Navigation() {
  const navigate= useNavigate();
  const getMainPage=()=>{      
   navigate('/')
  }
    return (
      <div className="mainHeader">
         ZKPHype
         <div className='centerHeader' onClick={getMainPage}>Home</div>
         
      </div>
    );
  }
  
  export default Navigation;
  