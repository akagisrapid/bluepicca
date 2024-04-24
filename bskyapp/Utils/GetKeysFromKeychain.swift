import Foundation
import Keys

func getBskyPasswordFromKeychain()-> String{
    return BskyappKeys().bskyPassword
}
